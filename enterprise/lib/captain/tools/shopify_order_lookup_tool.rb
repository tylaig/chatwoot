# frozen_string_literal: true

class Captain::Tools::ShopifyOrderLookupTool < Captain::Tools::BasePublicTool
  description 'Lookup customer orders in connected Shopify stores by purchase email, phone number, or order number (e.g. #1024). ALWAYS require purchase-email confirmation before revealing order details to the customer; returned emails are masked.'
  param :query, type: 'string', desc: 'Customer purchase email (preferred), order number (e.g. #31652), or phone number. Prefer email. Order-number-only searches that are ambiguous or unverified will NOT return customer PII.'

  def perform(tool_context, query: nil)
    state = tool_context.state || {}
    conversation = find_conversation(state)
    contact = find_contact(state) || conversation&.contact
    inbox_id = conversation&.inbox_id

    search_query = query.to_s.strip
    log_tool_usage('shopify_order_lookup', { query: search_query, conversation_id: conversation&.id, inbox_id: inbox_id })

    hooks_exist = @assistant.account.hooks.where(app_id: 'shopify', status: :enabled).exists?
    return 'No Shopify stores are currently connected to this account.' unless hooks_exist

    orders = Shopify::MultiStoreOrderFinderService.new(
      account: @assistant.account,
      contact: contact,
      query: search_query,
      inbox_id: inbox_id
    ).perform

    sync_contact_email(contact, search_query, orders, conversation: conversation)

    if orders.empty?
      log_tool_usage('no_orders_found', { query: search_query })
      return "No Shopify orders found for query: #{mask_email(search_query.presence || contact&.email || 'current contact')}"
    end

    privacy = privacy_gate(search_query, contact, orders)
    if privacy[:block]
      log_tool_usage('privacy_gate_blocked', { query: search_query, reason: privacy[:reason], count: orders.size })
      return privacy[:message]
    end

    log_tool_usage('orders_found', { query: search_query, count: orders.size })
    format_orders(orders.first(20))
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @assistant.account).capture_exception
    failure_result("Failed to lookup Shopify orders: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.account.hooks.where(app_id: 'shopify', status: :enabled).exists?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  STORE_ACCOUNT_DOMAIN_REGEX = /@(?:irafasg\.com|irafsg\.com|gamessafari\.com|safarigam\.es|barbagames\.com|gameboxbrasil\.com|gamesgl\.com)\z/i
  STORE_ACCOUNT_PREFIX_REGEX = /\A(?:gt\d+|saf\d+|minesaf|reddeadsafari|fc\d+|cod\d+|psn\d+|xbox\d+)/i

  def store_delivered_account_email?(email)
    em = email.to_s.strip.downcase
    return false if em.blank? || em.include?('*')
    return true if em.match?(STORE_ACCOUNT_DOMAIN_REGEX)

    local_part = em.split('@').first.to_s
    local_part.match?(STORE_ACCOUNT_PREFIX_REGEX)
  end

  def mask_email(value)
    s = value.to_s
    s.gsub(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i) do |email|
      local, domain = email.split('@', 2)
      next email if local.blank? || domain.blank?
      visible = local[0, [2, local.length].min]
      "#{visible}***@#{domain}"
    end
  end

  def mask_phone(phone)
    digits = phone.to_s.gsub(/\D/, '')
    return 'N/A' if digits.blank?
    return "***#{digits[-2..]}" if digits.length <= 4

    "***#{digits[-4..]}"
  end

  def mask_name(name)
    parts = name.to_s.strip.split(/\s+/)
    return 'Cliente' if parts.empty?
    return "#{parts.first[0]}***" if parts.size == 1

    "#{parts.first} #{parts.last[0]}***"
  end

  def extract_email_from_query(search_query)
    search_query.to_s[/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i]&.downcase
  end

  def order_number_only_query?(search_query)
    q = search_query.to_s.strip
    return false if q.blank?
    return false if extract_email_from_query(q).present?
    return false if q.gsub(/\D/, '').length >= 10 && q.match?(/\d{8,}/) && !q.match?(/#/)

    !!(q.match?(/\A#?\d{3,}\z/) || q.match?(/pedido\s*#?\d+/i) || q.match?(/\A[A-Z]?\d{4,}\z/i))
  end

  def privacy_gate(search_query, contact, orders)
    email_in_query = extract_email_from_query(search_query)
    email_in_query = nil if store_delivered_account_email?(email_in_query)
    contact_email = contact&.email.to_s.strip.downcase.presence
    contact_email = nil if store_delivered_account_email?(contact_email)

    verified_email = email_in_query.presence || contact_email
    distinct_customer_emails = orders.map { |o| o['email'].to_s.downcase }.reject(&:blank?).uniq
    order_only = order_number_only_query?(search_query)

    # Ambiguous: same order number hit multiple customers/stores with different emails
    if order_only && distinct_customer_emails.size > 1 && verified_email.blank?
      return {
        block: true,
        reason: 'ambiguous_order_number_no_email',
        message: <<~MSG.strip
          PRIVACY_GATE: Found #{orders.size} Shopify order match(es) for this order number across stores, but they belong to different purchase emails.
          Do NOT reveal any customer names, products, values, payment status, delivery status, or emails to the customer.
          Ask ONLY for the purchase email used at checkout to confirm identity, then call shopify_order_lookup again with that email (optionally with the order number).
          Never display a full purchase email — always mask it (ex: br***@gmail.com).
        MSG
      }
    end

    # Order-number-only without any verified purchase email on contact/query
    if order_only && verified_email.blank?
      return {
        block: true,
        reason: 'order_number_without_email',
        message: <<~MSG.strip
          PRIVACY_GATE: Order number lookup found #{orders.size} match(es), but purchase email was NOT confirmed yet.
          Do NOT reveal customer name, product, price, payment, delivery, phone, or email.
          Ask ONLY for the purchase email used at checkout to confirm ownership, then call shopify_order_lookup again with that email.
          Never display a full purchase email — always mask it (ex: br***@gmail.com).
        MSG
      }
    end

    # Email present but does not match any returned order email → do not leak other customers
    if verified_email.present? && distinct_customer_emails.any? && distinct_customer_emails.none? { |e| e == verified_email }
      return {
        block: true,
        reason: 'email_mismatch',
        message: <<~MSG.strip
          PRIVACY_GATE: The confirmed purchase email #{mask_email(verified_email)} does not match the order(s) found for this query.
          Do NOT reveal other customers' names, products, values, or emails.
          Ask the customer to double-check the purchase email / order number, or hand off to a human with a private note (masked email only).
        MSG
      }
    end

    # If verified email exists, filter to that customer's orders only
    if verified_email.present? && distinct_customer_emails.size > 1
      matched = orders.select { |o| o['email'].to_s.downcase == verified_email }
      if matched.any?
        orders.replace(matched)
      end
    end

    { block: false }
  end

  def sync_contact_email(contact, search_query, orders, conversation: nil)
    return if contact.blank?

    email_from_query = extract_email_from_query(search_query)
    email_from_query = nil if store_delivered_account_email?(email_from_query)
    email_from_orders = orders.find { |o| o['email'].present? && !store_delivered_account_email?(o['email']) }&.dig('email')&.downcase

    # Never auto-sync email from order-number-only lookups (prevents hijack / wrong merge)
    if order_number_only_query?(search_query) && email_from_query.blank?
      return
    end

    candidate = if orders.any?
                  email_from_query.presence || (email_from_orders.presence if email_from_query.present?)
                else
                  email_from_query.presence if contact.email.blank?
                end
    return if candidate.blank?
    return if store_delivered_account_email?(candidate)
    return if contact.email.to_s.downcase == candidate

    existing = contact.account.contacts.where.not(id: contact.id).find_by('LOWER(email) = ?', candidate)
    if existing.present?
      active_wa = whatsapp_session_contact?(contact, conversation)
      preserved_phone = contact.phone_number if active_wa && contact.phone_number.present?
      preserved_identifier = contact.identifier if active_wa && contact.identifier.to_s.end_with?('@lid')

      merged = ContactMergeAction.new(
        account: contact.account,
        base_contact: existing,
        mergee_contact: contact
      ).perform

      restore_attrs = {}
      restore_attrs[:phone_number] = preserved_phone if preserved_phone.present? && merged.phone_number != preserved_phone
      restore_attrs[:identifier] = preserved_identifier if preserved_identifier.present? && merged.identifier != preserved_identifier
      merged.update!(restore_attrs) if restore_attrs.present?
    else
      contact.update!(email: candidate)
    end
  rescue StandardError => e
    Rails.logger.warn("[Captain::Tools::ShopifyOrderLookupTool] Could not sync contact email: #{e.message}")
  end

  def whatsapp_session_contact?(contact, conversation)
    return true if contact.identifier.to_s.end_with?('@lid')
    return true if conversation&.inbox&.channel_type == 'Channel::Whatsapp'

    false
  end

  def format_orders(orders)
    lines = ["Found #{orders.size} Shopify order(s):"]
    orders.each do |order|
      items_summary = Array(order['line_items']).map do |item|
        variant = item['variant_title'].present? ? " (#{item['variant_title']})" : ''
        sku = item['sku'].present? ? " [SKU: #{item['sku']}]" : ''
        "#{item['quantity']}x #{item['title']}#{variant}#{sku}"
      end.join(', ')

      elapsed = if order['minutes_since_created'].present?
                  "#{order['minutes_since_created']} minutes ago (within_1h_window=#{order['within_one_hour_window']})"
                else
                  'unknown'
                end

      tracking_summary = Array(order['fulfillments']).map do |f|
        "#{f['tracking_company'] || 'Digital'}: #{f['tracking_number'] || 'N/A'}"
      end.join('; ')

      lines << <<~ORDER.strip
        - Store: #{order['store_name']} (#{order['shop_domain']})
          Order: #{order['name']} (ID: #{order['id']})
          Customer: #{mask_name(order['customer_name'])} | Email: #{mask_email(order['email'])} | Phone: #{mask_phone(order['phone'])}
          Created At: #{order['created_at']} (Elapsed: #{elapsed})
          Financial Status (Payment): #{order['financial_status']} (Method: #{order['payment_method'].presence || order['gateway'].presence || 'PIX / Card'})
          Fulfillment Status (Delivery): #{order['fulfillment_status']}
          Total: #{order['total_price']} #{order['currency']} (Subtotal: #{order['subtotal_price']} | Discounts: #{order['total_discounts']})
          Items: #{items_summary.presence || 'N/A'}
          Tracking / Fulfillments: #{tracking_summary.presence || 'Pending / Digital Automatic'}
          Note: #{order['note'].presence || 'none'}
          Tags: #{order['tags'].presence || 'none'}
          Admin URL: #{order['admin_url']}
          PRIVACY: Purchase email above is MASKED. Never show the full purchase email to the customer. Confirm ownership via email match before listing details.
      ORDER
    end
    lines.join("\n\n")
  end
end

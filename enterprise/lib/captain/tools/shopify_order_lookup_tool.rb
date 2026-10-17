# frozen_string_literal: true

class Captain::Tools::ShopifyOrderLookupTool < Captain::Tools::BasePublicTool
  description 'Lookup customer orders in connected Shopify stores by purchase email, phone number, or order number (e.g. #1024).'
  param :query, type: 'string', desc: 'Customer email address, order number (e.g. #31652), or phone number to search for in Shopify'

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

    sync_contact_email(contact, search_query, orders)

    if orders.empty?
      log_tool_usage('no_orders_found', { query: search_query })
      return "No Shopify orders found for query: #{search_query.presence || contact&.email || 'current contact'}"
    end

    log_tool_usage('orders_found', { query: search_query, count: orders.size })
    format_orders(orders.first(8))
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

  def sync_contact_email(contact, search_query, orders)
    return if contact.blank? || contact.email.present?

    candidate = if search_query.include?('@')
                  search_query.downcase
                else
                  orders.find { |o| o['email'].present? }&.dig('email')&.downcase
                end
    return if candidate.blank?

    contact.update(email: candidate)
  rescue StandardError => e
    Rails.logger.warn("[Captain::Tools::ShopifyOrderLookupTool] Could not sync contact email: #{e.message}")
  end

  def format_orders(orders)
    lines = ["Found #{orders.size} Shopify order(s):"]
    orders.each do |order|
      items_summary = Array(order['line_items']).map do |item|
        variant = item['variant_title'].present? ? " (#{item['variant_title']})" : ''
        "#{item['quantity']}x #{item['title']}#{variant}"
      end.join(', ')

      elapsed = if order['minutes_since_created'].present?
                  "#{order['minutes_since_created']} minutes ago (within_1h_window=#{order['within_one_hour_window']})"
                else
                  'unknown'
                end

      lines << <<~ORDER.strip
        - Store: #{order['store_name']} (#{order['shop_domain']})
          Order: #{order['name']} (ID: #{order['id']})
          Customer Email: #{order['email']}
          Created At: #{order['created_at']} (Elapsed: #{elapsed})
          Financial Status: #{order['financial_status']}
          Fulfillment Status: #{order['fulfillment_status']}
          Total: #{order['total_price']} #{order['currency']}
          Items: #{items_summary.presence || 'N/A'}
          Tags: #{order['tags'].presence || 'none'}
          Admin URL: #{order['admin_url']}
      ORDER
    end
    lines.join("\n\n")
  end
end

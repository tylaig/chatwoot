# frozen_string_literal: true

class Shopify::MultiStoreOrderFinderService
  API_VERSION = '2025-01'
  ORDER_FIELDS = 'id,name,email,phone,created_at,updated_at,total_price,currency,fulfillment_status,financial_status,cancelled_at,cancel_reason,tags,line_items'

  def initialize(account:, contact: nil, query: nil, inbox_id: nil, hook_id: nil)
    @account = account
    @contact = contact
    @query = query.to_s.strip
    @inbox_id = inbox_id.presence&.to_i
    @hook_id = hook_id.presence&.to_i
  end

  def perform
    hooks = resolve_hooks
    return [] if hooks.empty?

    threads = hooks.map do |hook|
      Thread.new do
        Rails.application.executor.wrap do
          fetch_orders_from_hook(hook)
        end
      rescue StandardError => e
        Rails.logger.warn("[Shopify::MultiStoreOrderFinderService] Error on hook=#{hook.id} (#{hook.reference_id}): #{e.message}")
        []
      end
    end

    orders = threads.flat_map(&:value)
    sort_orders(orders)
  end

  def self.verify_connection!(shop_domain:, access_token:)
    normalized_domain = Shopify::ShopDomain.normalize(shop_domain)
    raise ArgumentError, 'Domínio .myshopify.com inválido' unless Shopify::ShopDomain.valid?(normalized_domain)
    raise ArgumentError, 'Admin API Access Token é obrigatório' if access_token.blank?

    response = HTTParty.get(
      "https://#{normalized_domain}/admin/api/#{API_VERSION}/shop.json",
      headers: {
        'X-Shopify-Access-Token' => access_token.to_s.strip,
        'Content-Type' => 'application/json'
      },
      timeout: 10
    )

    unless response.success? && response.parsed_response.is_a?(Hash) && response.parsed_response['shop'].present?
      error_detail = response.parsed_response.is_a?(Hash) ? response.parsed_response['errors'] : response.body
      raise StandardError, "Falha ao autenticar na Shopify (#{response.code}): #{error_detail}"
    end

    response.parsed_response['shop']
  end

  private

  def resolve_hooks
    scope = @account.hooks.where(app_id: 'shopify', status: :enabled)
    scope = scope.where(id: @hook_id) if @hook_id.present?
    hooks = scope.to_a
    return [] if hooks.empty?

    if @inbox_id.present?
      # Prioritize hooks explicitly linked to this inbox, but still query all if none or if cross-store search is needed
      hooks.sort_by do |h|
        inbox_ids = Array(h.settings&.dig('inbox_ids')).map(&:to_i)
        inbox_ids.include?(@inbox_id) ? 0 : 1
      end
    else
      hooks
    end
  end

  def fetch_orders_from_hook(hook)
    raw_orders = []

    if order_number_query?
      raw_orders.concat(fetch_orders_by_name(hook, normalized_order_name))
    end

    search_terms = build_customer_search_terms
    if search_terms.any?
      customers = search_customers(hook, search_terms)
      customers.first(3).each do |customer|
        raw_orders.concat(fetch_orders_by_customer(hook, customer['id']))
      end
    end

    if raw_orders.empty? && email_queries.any?
      email_queries.each do |email|
        raw_orders.concat(fetch_orders_by_email(hook, email))
      end
    end

    raw_orders.uniq { |o| o['id'] }.map { |order| serialize_order(hook, order) }
  end

  def order_number_query?
    return false if @query.blank?

    @query.match?(/\A#?\d{3,10}\z/) || @query.match?(/\A#[A-Za-z0-9\-_]{3,16}\z/)
  end

  def normalized_order_name
    @query.start_with?('#') ? @query : "##{@query}"
  end

  def email_queries
    emails = []
    emails << @query.downcase if @query.present? && @query.include?('@')
    emails << @contact.email.downcase if @contact&.email.present?
    emails.uniq
  end

  def phone_queries
    phones = []
    if @query.present? && !@query.include?('@') && !order_number_query?
      digits = @query.gsub(/\D/, '')
      phones << @query if digits.length >= 8
    end
    phones << @contact.phone_number if @contact&.phone_number.present?
    phones.uniq
  end

  def build_customer_search_terms
    terms = []
    email_queries.each { |email| terms << "email:#{email}" }
    phone_queries.each { |phone| terms << "phone:#{phone}" }
    terms.uniq
  end

  def search_customers(hook, terms)
    res = shopify_get(
      hook,
      'customers/search.json',
      query: terms.join(' OR '),
      fields: 'id,email,phone,first_name,last_name'
    )
    res['customers'] || []
  end

  def fetch_orders_by_customer(hook, customer_id)
    res = shopify_get(
      hook,
      'orders.json',
      customer_id: customer_id,
      status: 'any',
      limit: 15,
      fields: ORDER_FIELDS
    )
    res['orders'] || []
  end

  def fetch_orders_by_name(hook, order_name)
    res = shopify_get(
      hook,
      'orders.json',
      name: order_name,
      status: 'any',
      limit: 10,
      fields: ORDER_FIELDS
    )
    orders = res['orders'] || []
    return orders if orders.any?

    # Also try without '#' prefix if needed
    clean_name = order_name.sub(/\A#/, '')
    res_alt = shopify_get(
      hook,
      'orders.json',
      name: clean_name,
      status: 'any',
      limit: 10,
      fields: ORDER_FIELDS
    )
    res_alt['orders'] || []
  end

  def fetch_orders_by_email(hook, email)
    res = shopify_get(
      hook,
      'orders.json',
      email: email,
      status: 'any',
      limit: 15,
      fields: ORDER_FIELDS
    )
    res['orders'] || []
  end

  def shopify_get(hook, endpoint, query_params = {})
    response = HTTParty.get(
      "https://#{hook.reference_id}/admin/api/#{API_VERSION}/#{endpoint}",
      query: query_params,
      headers: {
        'X-Shopify-Access-Token' => hook.access_token.to_s.strip,
        'Content-Type' => 'application/json'
      },
      timeout: 10
    )
    return {} unless response.success? && response.parsed_response.is_a?(Hash)

    response.parsed_response
  end

  def serialize_order(hook, order)
    created_time = Time.zone.parse(order['created_at'].to_s)
    minutes_since_created = created_time ? ((Time.current - created_time) / 60.0).round : nil
    store_name = hook.settings&.dig('store_name').presence || hook.reference_id
    inbox_ids = Array(hook.settings&.dig('inbox_ids')).map(&:to_i)

    {
      'id' => order['id'],
      'name' => order['name'].presence || "##{order['id']}",
      'email' => order['email'],
      'phone' => order['phone'],
      'created_at' => order['created_at'],
      'updated_at' => order['updated_at'],
      'minutes_since_created' => minutes_since_created,
      'within_one_hour_window' => minutes_since_created.present? ? minutes_since_created < 60 : false,
      'total_price' => order['total_price'],
      'currency' => order['currency'],
      'financial_status' => order['financial_status'],
      'fulfillment_status' => order['fulfillment_status'].presence || 'unfulfilled',
      'cancelled_at' => order['cancelled_at'],
      'cancel_reason' => order['cancel_reason'],
      'tags' => order['tags'],
      'hook_id' => hook.id,
      'shop_domain' => hook.reference_id,
      'store_name' => store_name,
      'inbox_ids' => inbox_ids,
      'matches_current_inbox' => @inbox_id.present? && inbox_ids.include?(@inbox_id),
      'admin_url' => "https://#{hook.reference_id}/admin/orders/#{order['id']}",
      'line_items' => Array(order['line_items']).map do |item|
        {
          'id' => item['id'],
          'title' => item['title'],
          'variant_title' => item['variant_title'],
          'sku' => item['sku'],
          'quantity' => item['quantity'],
          'price' => item['price'],
          'fulfillment_status' => item['fulfillment_status']
        }
      end
    }
  end

  def sort_orders(orders)
    orders.sort_by do |o|
      inbox_priority = o['matches_current_inbox'] ? 0 : 1
      timestamp = Time.zone.parse(o['created_at'].to_s)&.to_i || 0
      [inbox_priority, -timestamp]
    end
  end
end

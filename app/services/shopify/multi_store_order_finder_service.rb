# frozen_string_literal: true

class Shopify::MultiStoreOrderFinderService
  API_VERSION = '2025-01'
  ORDER_FIELDS = 'id,name,email,phone,created_at,updated_at,total_price,currency,fulfillment_status,financial_status,cancelled_at,cancel_reason,tags,customer,line_items'

  def initialize(account:, contact: nil, query: nil, inbox_id: nil, hook_id: nil, user: nil)
    @account = account
    @contact = contact
    @query = query.to_s.strip
    @inbox_id = inbox_id.presence&.to_i
    @hook_id = hook_id.presence&.to_i
    @user = user
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

  def perform_customers
    hooks = resolve_hooks
    return [] if hooks.empty?

    threads = hooks.map do |hook|
      Thread.new do
        Rails.application.executor.wrap do
          fetch_customers_from_hook(hook)
        end
      rescue StandardError => e
        Rails.logger.warn("[Shopify::MultiStoreOrderFinderService] Customers error on hook=#{hook.id}: #{e.message}")
        []
      end
    end

    threads.flat_map(&:value)
  end

  def self.mock_token?(access_token)
    token = access_token.to_s.strip
    token.blank? || token.start_with?('mock_', 'demo_', 'shpat_mock')
  end

  def self.hook_accessible_by_user?(hook, user, account)
    return true if user.blank?

    account_user = account.account_users.find_by(user_id: user.id)
    return true if account_user&.administrator?

    allowed_agent_ids = Array(hook.settings&.dig('agent_ids')).map(&:to_i).reject(&:zero?)
    return true if allowed_agent_ids.empty?

    allowed_agent_ids.include?(user.id.to_i)
  end

  def self.verify_connection!(shop_domain:, access_token: nil, store_name: nil)
    normalized_domain = Shopify::ShopDomain.normalize(shop_domain.presence || store_name)
    raise ArgumentError, 'Domínio .myshopify.com inválido' unless Shopify::ShopDomain.valid?(normalized_domain)

    if mock_token?(access_token)
      slug = normalized_domain.sub(/\.myshopify\.(?:com|io)\z/, '')
      display_name = store_name.to_s.strip.presence || slug.tr('-', ' ').split.map(&:capitalize).join(' ')
      return {
        'name' => display_name,
        'email' => "suporte@#{slug}.com",
        'domain' => "#{slug}.com",
        'auth_mode' => 'mock',
        'connection_status' => 'connected'
      }
    end

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

    response.parsed_response['shop'].merge(
      'auth_mode' => 'access_token',
      'connection_status' => 'connected'
    )
  end

  def self.fetch_products_for_hook!(hook)
    is_mock = hook.settings&.dig('auth_mode') == 'mock' || mock_token?(hook.access_token)
    if is_mock
      return build_mock_products_for_hook(hook)
    end

    response = HTTParty.get(
      "https://#{hook.reference_id}/admin/api/#{API_VERSION}/products.json",
      query: { limit: 50, fields: 'id,title,handle,status,vendor,product_type,variants,images,updated_at' },
      headers: {
        'X-Shopify-Access-Token' => hook.access_token.to_s.strip,
        'Content-Type' => 'application/json'
      },
      timeout: 15
    )

    unless response.success? && response.parsed_response.is_a?(Hash)
      raise StandardError, "Falha ao buscar produtos na Shopify (#{response.code})"
    end

    Array(response.parsed_response['products']).map do |prod|
      first_variant = Array(prod['variants']).first || {}
      first_image = Array(prod['images']).first || {}
      {
        'id' => prod['id'],
        'title' => prod['title'],
        'handle' => prod['handle'],
        'status' => prod['status'] || 'active',
        'product_type' => prod['product_type'],
        'price' => first_variant['price'] || '0.00',
        'sku' => first_variant['sku'],
        'inventory_quantity' => first_variant['inventory_quantity'] || 99,
        'image_url' => first_image['src'],
        'store_name' => hook.settings&.dig('store_name').presence || hook.reference_id,
        'hook_id' => hook.id
      }
    end
  end

  def self.build_mock_products_for_hook(hook)
    ref = hook.reference_id.to_s.downcase
    store_name = hook.settings&.dig('store_name').presence || hook.reference_id

    if ref.include?('barba') || store_name.downcase.include?('barba')
      [
        {
          'id' => 501_001,
          'title' => 'EA SPORTS FC 27 - Xbox Series X|S & Xbox One (Mídia Digital)',
          'handle' => 'ea-sports-fc-27-xbox',
          'status' => 'active',
          'product_type' => 'Jogos Xbox',
          'price' => '214.50',
          'sku' => 'BG-EAFC27-XBOX',
          'inventory_quantity' => 145,
          'image_url' => 'https://barbagames.com/cdn/shop/files/fc27-xbox.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 501_002,
          'title' => 'GTA VI Standard Edition - PS5 Digital (Pré-Venda)',
          'handle' => 'gta-vi-ps5-digital',
          'status' => 'active',
          'product_type' => 'Jogos PS5',
          'price' => '149.90',
          'sku' => 'BG-GTA6-PS5',
          'inventory_quantity' => 88,
          'image_url' => 'https://barbagames.com/cdn/shop/files/gta6-ps5.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 501_003,
          'title' => 'Call of Duty: Black Ops 6 - Cross-Gen Bundle (Xbox / PS5)',
          'handle' => 'cod-bo6-bundle',
          'status' => 'active',
          'product_type' => 'Jogos Ação',
          'price' => '129.90',
          'sku' => 'BG-COD-BO6',
          'inventory_quantity' => 64,
          'image_url' => 'https://barbagames.com/cdn/shop/files/bo6.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        }
      ]
    elsif ref.include?('gamebox') || store_name.downcase.include?('gamebox')
      [
        {
          'id' => 502_001,
          'title' => 'Assinatura Xbox Game Pass Ultimate - 12 Meses',
          'handle' => 'xbox-game-pass-ultimate-12m',
          'status' => 'active',
          'product_type' => 'Assinaturas',
          'price' => '179.90',
          'sku' => 'GBX-GPU-12M',
          'inventory_quantity' => 310,
          'image_url' => 'https://gameboxbrasil.com/cdn/shop/files/IMG_3468_ed6eda99-80d9-46d6-9340-d06f3d6410e9.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 502_002,
          'title' => 'Forza Horizon 5 Premium Edition - Xbox / PC',
          'handle' => 'forza-horizon-5-premium',
          'status' => 'active',
          'product_type' => 'Corrida',
          'price' => '89.90',
          'sku' => 'GBX-FH5-PREM',
          'inventory_quantity' => 92,
          'image_url' => 'https://gameboxbrasil.com/cdn/shop/files/fh5.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 502_003,
          'title' => 'Gift Card Xbox Live R$ 100 - Código 25 Dígitos',
          'handle' => 'gift-card-xbox-100',
          'status' => 'active',
          'product_type' => 'Gift Cards',
          'price' => '94.90',
          'sku' => 'GBX-GIFT-100',
          'inventory_quantity' => 500,
          'image_url' => 'https://gameboxbrasil.com/cdn/shop/files/gift100.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        }
      ]
    elsif ref.include?('gamesgl') || store_name.downcase.include?('gl')
      [
        {
          'id' => 503_001,
          'title' => 'EA SPORTS FC 27 - PC Steam Offline (Modo Carreira)',
          'handle' => 'ea-sports-fc-27-steam-offline',
          'status' => 'active',
          'product_type' => 'PC Steam',
          'price' => '49.90',
          'sku' => 'GGL-FC27-STEAM-OFF',
          'inventory_quantity' => 420,
          'image_url' => 'https://gamesgl.com/cdn/shop/files/Untitled_design_16.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 503_002,
          'title' => 'Black Myth: Wukong - PC Steam Deluxe Edition',
          'handle' => 'black-myth-wukong-pc',
          'status' => 'active',
          'product_type' => 'PC Steam',
          'price' => '119.90',
          'sku' => 'GGL-WUKONG-PC',
          'inventory_quantity' => 115,
          'image_url' => 'https://gamesgl.com/cdn/shop/files/wukong.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 503_003,
          'title' => 'Elden Ring: Shadow of the Erdtree - PC Steam',
          'handle' => 'elden-ring-sote-pc',
          'status' => 'active',
          'product_type' => 'PC Steam',
          'price' => '79.90',
          'sku' => 'GGL-ELDEN-PC',
          'inventory_quantity' => 75,
          'image_url' => 'https://gamesgl.com/cdn/shop/files/eldenring.png',
          'store_name' => store_name,
          'hook_id' => hook.id
        }
      ]
    else
      [
        {
          'id' => 500_001,
          'title' => 'EA SPORTS FC 27 - Steam Online + 500 mil FC Coins Ultimate Team',
          'handle' => 'ea-sports-fc-27-steam-online',
          'status' => 'active',
          'product_type' => 'EA FC 27',
          'price' => '230.00',
          'sku' => 'GS-FC27-ULT-500K',
          'inventory_quantity' => 250,
          'image_url' => 'https://gamessafari.com/products/gamepassultimate',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 500_002,
          'title' => '100 mil FC Coins - EA SPORTS FC 27 (Xbox / PS5 / PC)',
          'handle' => 'fc-coin-100-mil-ultimate-team',
          'status' => 'active',
          'product_type' => 'FC Coins',
          'price' => '69.90',
          'sku' => 'GS-FCCOINS-100K',
          'inventory_quantity' => 999,
          'image_url' => 'https://gamessafari.com.br/products/fc-coin-100-mil-ultimate-team-ea-xbox-playstation-fifa-coins-ea-fc-27',
          'store_name' => store_name,
          'hook_id' => hook.id
        },
        {
          'id' => 500_003,
          'title' => 'Assinatura Xbox Game Pass Ultimate - Acesso Completo',
          'handle' => 'gamepassultimate',
          'status' => 'active',
          'product_type' => 'Assinaturas',
          'price' => '59.90',
          'sku' => 'GS-GAMEPASS-ULT',
          'inventory_quantity' => 180,
          'image_url' => 'https://gamessafari.com/products/assinatura-gam',
          'store_name' => store_name,
          'hook_id' => hook.id
        }
      ]
    end
  end

  private

  def resolve_hooks
    scope = @account.hooks.where(app_id: 'shopify', status: :enabled)
    scope = scope.where(id: @hook_id) if @hook_id.present?
    hooks = scope.to_a.select { |h| self.class.hook_accessible_by_user?(h, @user, @account) }
    return [] if hooks.empty?

    if @inbox_id.present?
      hooks.sort_by do |h|
        inbox_ids = Array(h.settings&.dig('inbox_ids')).map(&:to_i)
        inbox_ids.include?(@inbox_id) ? 0 : 1
      end
    else
      hooks
    end
  end

  def mock_hook?(hook)
    hook.settings&.dig('auth_mode') == 'mock' || self.class.mock_token?(hook.access_token)
  end

  def fetch_customers_from_hook(hook)
    store_name = hook.settings&.dig('store_name').presence || hook.reference_id
    if mock_hook?(hook)
      orders = filter_mock_orders_for_hook(hook)
      grouped = orders.group_by { |o| o['email'].to_s.downcase }
      return grouped.map do |email, cust_orders|
        first_ord = cust_orders.first
        cust_info = first_ord['customer'] || {}
        total_spent = cust_orders.sum { |o| o['total_price'].to_f }
        {
          'id' => cust_info['id'] || first_ord['id'],
          'name' => cust_info['name'].presence || email.split('@').first.tr('._-', ' ').split.map(&:capitalize).join(' '),
          'email' => first_ord['email'],
          'phone' => first_ord['phone'],
          'orders_count' => cust_orders.size,
          'total_spent' => format('%.2f', total_spent),
          'currency' => first_ord['currency'] || 'BRL',
          'last_order_name' => first_ord['name'],
          'last_order_at' => first_ord['created_at'],
          'store_name' => store_name,
          'shop_domain' => hook.reference_id,
          'hook_id' => hook.id
        }
      end
    end

    endpoint = @query.present? ? 'customers/search.json' : 'customers.json'
    params = { limit: 30, fields: 'id,first_name,last_name,email,phone,orders_count,total_spent,currency,last_order_name,updated_at' }
    params[:query] = @query if @query.present?
    res = shopify_get(hook, endpoint, params)
    Array(res['customers']).map do |c|
      full_name = [c['first_name'], c['last_name']].compact.join(' ').strip
      {
        'id' => c['id'],
        'name' => full_name.presence || c['email'].to_s,
        'email' => c['email'],
        'phone' => c['phone'],
        'orders_count' => c['orders_count'] || 0,
        'total_spent' => c['total_spent'] || '0.00',
        'currency' => c['currency'] || 'BRL',
        'last_order_name' => c['last_order_name'],
        'last_order_at' => c['updated_at'],
        'store_name' => store_name,
        'shop_domain' => hook.reference_id,
        'hook_id' => hook.id
      }
    end
  end

  def fetch_orders_from_hook(hook)
    if mock_hook?(hook)
      raw_orders = filter_mock_orders_for_hook(hook)
      return raw_orders.map { |order| serialize_order(hook, order) }
    end

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

    if raw_orders.empty? && @contact.blank? && @query.blank?
      res = shopify_get(hook, 'orders.json', status: 'any', limit: 25, fields: ORDER_FIELDS)
      raw_orders.concat(res['orders'] || [])
    end

    raw_orders.uniq { |o| o['id'] }.map { |order| serialize_order(hook, order) }
  end

  def filter_mock_orders_for_hook(hook)
    catalog = build_mock_orders_for_hook(hook)
    return catalog if @query.blank?

    q = @query.downcase.strip
    clean_num = q.sub(/\A#/, '')

    matched = catalog.select do |order|
      order['name'].to_s.downcase.include?(clean_num) ||
        order['email'].to_s.downcase.include?(q) ||
        order.dig('customer', 'name').to_s.downcase.include?(q) ||
        order['phone'].to_s.gsub(/\D/, '').include?(q.gsub(/\D/, '').presence || '__none__') ||
        Array(order['line_items']).any? { |li| li['title'].to_s.downcase.include?(q) || li['sku'].to_s.downcase.include?(q) }
    end

    return matched if matched.any?

    if order_number_query? || q.include?('@')
      [synthesize_dynamic_mock_order(hook, q)]
    else
      []
    end
  end

  def build_mock_orders_for_hook(hook)
    ref = hook.reference_id.to_s.downcase
    store_name = hook.settings&.dig('store_name').to_s
    contact_email = @contact&.email
    contact_phone = @contact&.phone_number
    contact_name = @contact&.name
    now = Time.current

    if ref.include?('barba') || store_name.downcase.include?('barba')
      [
        {
          'id' => 902_101,
          'name' => '#BG-41820',
          'email' => contact_email.presence || 'lucas.oliveira@gmail.com',
          'phone' => contact_phone.presence || '+5511997123456',
          'customer' => {
            'id' => 701,
            'name' => contact_name.presence || 'Lucas Oliveira'
          },
          'created_at' => (now - 18.minutes).iso8601,
          'updated_at' => (now - 5.minutes).iso8601,
          'total_price' => '214.50',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'unfulfilled',
          'tags' => 'envio-automatico, xbox-series',
          'line_items' => [
            {
              'id' => 11,
              'title' => 'EA SPORTS FC 27 - Xbox Series X|S & Xbox One (Mídia Digital)',
              'variant_title' => 'Licença Primária · Entrega em até 1h',
              'sku' => 'BG-EAFC27-XBOX',
              'quantity' => 1,
              'price' => '214.50',
              'fulfillment_status' => nil
            }
          ]
        },
        {
          'id' => 902_102,
          'name' => '#BG-41509',
          'email' => contact_email.presence || 'rafael.mendes@hotmail.com',
          'phone' => contact_phone.presence || '+5521988451230',
          'customer' => {
            'id' => 702,
            'name' => contact_name.presence || 'Rafael Mendes'
          },
          'created_at' => (now - 3.days).iso8601,
          'updated_at' => (now - 3.days).iso8601,
          'total_price' => '149.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue, ps5',
          'line_items' => [
            {
              'id' => 12,
              'title' => 'GTA VI Standard Edition - PS5 Digital',
              'variant_title' => 'Conta Primária PS5',
              'sku' => 'BG-GTA6-PS5',
              'quantity' => 1,
              'price' => '149.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        }
      ]
    elsif ref.include?('gamebox') || store_name.downcase.include?('gamebox')
      [
        {
          'id' => 903_201,
          'name' => '#GBX-88210',
          'email' => contact_email.presence || 'gabriel.costa@uol.com.br',
          'phone' => contact_phone.presence || '+5531991239876',
          'customer' => {
            'id' => 801,
            'name' => contact_name.presence || 'Gabriel Costa'
          },
          'created_at' => (now - 34.minutes).iso8601,
          'updated_at' => (now - 10.minutes).iso8601,
          'total_price' => '179.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'unfulfilled',
          'tags' => 'gamepass, 12-meses',
          'line_items' => [
            {
              'id' => 21,
              'title' => 'Assinatura Xbox Game Pass Ultimate - 12 Meses',
              'variant_title' => 'Código 25 Dígitos + Ativação Guiada',
              'sku' => 'GBX-GPU-12M',
              'quantity' => 1,
              'price' => '179.90',
              'fulfillment_status' => nil
            }
          ]
        },
        {
          'id' => 903_202,
          'name' => '#GBX-87904',
          'email' => contact_email.presence || 'amanda.silva@gmail.com',
          'phone' => contact_phone.presence || '+5541996543210',
          'customer' => {
            'id' => 802,
            'name' => contact_name.presence || 'Amanda Silva'
          },
          'created_at' => (now - 5.days).iso8601,
          'updated_at' => (now - 5.days).iso8601,
          'total_price' => '89.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue',
          'line_items' => [
            {
              'id' => 22,
              'title' => 'Forza Horizon 5 Premium Edition - Xbox / PC',
              'variant_title' => 'Mídia Digital Completa',
              'sku' => 'GBX-FH5-PREM',
              'quantity' => 1,
              'price' => '89.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        }
      ]
    elsif ref.include?('gamesgl') || store_name.downcase.include?('gl')
      [
        {
          'id' => 904_301,
          'name' => '#GGL-19402',
          'email' => contact_email.presence || 'pedro.almeida@gmail.com',
          'phone' => contact_phone.presence || '+5551993456789',
          'customer' => {
            'id' => 901,
            'name' => contact_name.presence || 'Pedro Almeida'
          },
          'created_at' => (now - 95.minutes).iso8601,
          'updated_at' => (now - 65.minutes).iso8601,
          'total_price' => '49.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'unfulfilled',
          'tags' => 'steam-offline, atraso-verificacao',
          'line_items' => [
            {
              'id' => 31,
              'title' => 'EA SPORTS FC 27 - PC Steam Offline',
              'variant_title' => 'Acesso Imediato Modo Carreira',
              'sku' => 'GGL-FC27-STEAM-OFF',
              'quantity' => 1,
              'price' => '49.90',
              'fulfillment_status' => nil
            }
          ]
        },
        {
          'id' => 904_302,
          'name' => '#GGL-19115',
          'email' => contact_email.presence || 'thiago.rocha@outlook.com',
          'phone' => contact_phone.presence || '+5581994561234',
          'customer' => {
            'id' => 902,
            'name' => contact_name.presence || 'Thiago Rocha'
          },
          'created_at' => (now - 7.days).iso8601,
          'updated_at' => (now - 7.days).iso8601,
          'total_price' => '119.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue',
          'line_items' => [
            {
              'id' => 32,
              'title' => 'Black Myth: Wukong - PC Steam',
              'variant_title' => 'Edição Deluxe',
              'sku' => 'GGL-WUKONG-PC',
              'quantity' => 1,
              'price' => '119.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        }
      ]
    else
      # Default / Games Safari
      [
        {
          'id' => 901_001,
          'name' => '#31652',
          'email' => contact_email.presence || 'matheus.ferreira@gamessafari.com',
          'phone' => contact_phone.presence || '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => contact_name.presence || 'Matheus Ferreira'
          },
          'created_at' => (now - 24.minutes).iso8601,
          'updated_at' => (now - 12.minutes).iso8601,
          'total_price' => '230.00',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'unfulfilled',
          'tags' => 'fc-coins, ultimate-team',
          'line_items' => [
            {
              'id' => 1,
              'title' => 'EA SPORTS FC 27 - Steam Online + 500 mil FC Coins Ultimate Team',
              'variant_title' => 'Edição Ultimate · Entrega Automática (Até 1h)',
              'sku' => 'GS-FC27-ULT-500K',
              'quantity' => 1,
              'price' => '230.00',
              'fulfillment_status' => nil
            }
          ]
        },
        {
          'id' => 901_002,
          'name' => '#31410',
          'email' => contact_email.presence || 'bruno.santos@gmail.com',
          'phone' => contact_phone.presence || '+5511987651234',
          'customer' => {
            'id' => 602,
            'name' => contact_name.presence || 'Bruno Santos'
          },
          'created_at' => (now - 2.days).iso8601,
          'updated_at' => (now - 2.days).iso8601,
          'total_price' => '69.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue, fc-coins',
          'line_items' => [
            {
              'id' => 2,
              'title' => '100 mil FC Coins - EA SPORTS FC 27 (Xbox / PS5 / PC)',
              'variant_title' => 'Transferência Segura Comfort Trade',
              'sku' => 'GS-FCCOINS-100K',
              'quantity' => 1,
              'price' => '69.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        }
      ]
    end
  end

  def synthesize_dynamic_mock_order(hook, query_text)
    now = Time.current
    order_name = order_number_query? ? normalized_order_name.upcase : "##{rand(32_000..39_999)}"
    email_val = query_text.include?('@') ? query_text : (@contact&.email.presence || 'comprador@gamessafari.com')
    store_title = hook.settings&.dig('store_name').presence || hook.reference_id

    {
      'id' => (hook.id.to_i * 100_000) + order_name.gsub(/\D/, '').to_i,
      'name' => order_name,
      'email' => email_val,
      'phone' => @contact&.phone_number.presence || '+5511998765432',
      'customer' => {
        'id' => 999,
        'name' => @contact&.name.presence || 'Cliente Shopify'
      },
      'created_at' => (now - 28.minutes).iso8601,
      'updated_at' => (now - 5.minutes).iso8601,
      'total_price' => '199.90',
      'currency' => 'BRL',
      'financial_status' => 'paid',
      'fulfillment_status' => 'unfulfilled',
      'tags' => 'mock-search, entrega-1h',
      'line_items' => [
        {
          'id' => 99,
          'title' => "Pedido Digital (#{store_title}) - EA SPORTS FC 27 + Bônus",
          'variant_title' => 'Mídia Digital · Processando Envio',
          'sku' => 'MOCK-ORDER-ITEM',
          'quantity' => 1,
          'price' => '199.90',
          'fulfillment_status' => nil
        }
      ]
    }
  end

  def order_number_query?
    return false if @query.blank?

    @query.match?(/\A#?\d{3,10}\z/) || @query.match?(/\A#?[A-Za-z0-9\-_]{3,16}\z/) && @query.match?(/\d/)
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
    agent_ids = Array(hook.settings&.dig('agent_ids')).map(&:to_i)
    auth_mode = hook.settings&.dig('auth_mode').presence || (mock_hook?(hook) ? 'mock' : 'access_token')
    cust = order['customer'] || {}
    customer_name = cust['name'].presence || [cust['first_name'], cust['last_name']].compact.join(' ').strip.presence || order['email'].to_s.split('@').first

    {
      'id' => order['id'],
      'name' => order['name'].presence || "##{order['id']}",
      'email' => order['email'],
      'phone' => order['phone'],
      'customer_name' => customer_name,
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
      'auth_mode' => auth_mode,
      'inbox_ids' => inbox_ids,
      'agent_ids' => agent_ids,
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

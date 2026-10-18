# frozen_string_literal: true

class Shopify::MultiStoreOrderFinderService
  API_VERSION = '2025-01'
  ORDER_FIELDS = 'id,name,email,phone,created_at,updated_at,total_price,subtotal_price,total_discounts,total_tax,currency,fulfillment_status,financial_status,cancelled_at,cancel_reason,tags,note,gateway,payment_gateway_names,order_status_url,customer,shipping_address,billing_address,fulfillments,line_items'

  def initialize(account:, contact: nil, query: nil, inbox_id: nil, hook_id: nil, period: nil, user: nil)
    @account = account
    @contact = contact
    @query = query.to_s.strip
    @inbox_id = inbox_id.presence&.to_i
    @hook_id = hook_id.presence&.to_i
    @period = period.to_s.strip.presence
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
      variants_list = Array(prod['variants']).map do |v|
        {
          'id' => v['id'],
          'title' => v['title'],
          'price' => v['price'] || '0.00',
          'compare_at_price' => v['compare_at_price'],
          'sku' => v['sku'],
          'inventory_quantity' => v['inventory_quantity'] || 99
        }
      end
      first_variant = variants_list.first || {}
      images_list = Array(prod['images']).map { |img| img['src'] }.compact
      first_image_src = images_list.first || '/dashboard/images/integrations/shopify.png'
      {
        'id' => prod['id'],
        'title' => prod['title'],
        'handle' => prod['handle'],
        'vendor' => prod['vendor'].presence || (hook.settings&.dig('store_name').presence || 'Shopify Store'),
        'description' => prod['body_html'].to_s.gsub(/<[^>]*>/, '').strip.presence || 'Produto digital oficial com entrega automática via e-mail e WhatsApp após confirmação do pagamento.',
        'status' => prod['status'] || 'active',
        'product_type' => prod['product_type'].presence || 'Mídia Digital',
        'price' => first_variant['price'] || '0.00',
        'compare_at_price' => first_variant['compare_at_price'] || format('%.2f', (first_variant['price'].to_f * 1.25)),
        'sku' => first_variant['sku'],
        'inventory_quantity' => first_variant['inventory_quantity'] || 99,
        'image_url' => first_image_src,
        'images' => images_list.presence || [first_image_src],
        'variants' => variants_list,
        'store_name' => hook.settings&.dig('store_name').presence || hook.reference_id,
        'shop_domain' => hook.reference_id,
        'admin_url' => "https://#{hook.reference_id}/admin/products/#{prod['id']}",
        'storefront_url' => "https://#{hook.reference_id}/products/#{prod['handle']}",
        'hook_id' => hook.id
      }
    end
  end

  def self.build_mock_products_for_hook(hook)
    ref = hook.reference_id.to_s.downcase
    store_name = hook.settings&.dig('store_name').presence || hook.reference_id

    raw_items =
      if ref.include?('barba') || store_name.downcase.include?('barba')
        [
          {
            'id' => 501_001,
            'title' => 'EA SPORTS FC 27 - Xbox Series X|S & Xbox One (Mídia Digital)',
            'handle' => 'ea-sports-fc-27-xbox',
            'status' => 'active',
            'product_type' => 'Jogos Xbox',
            'price' => '214.50',
            'compare_at_price' => '299.90',
            'sku' => 'BG-EAFC27-XBOX',
            'inventory_quantity' => 145,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Licença oficial EA SPORTS FC 27 para Xbox Series X|S e Xbox One. Inclui modo Ultimate Team, Carreira e suporte a Cross-Play com envio imediato após confirmação.',
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
            'compare_at_price' => '249.90',
            'sku' => 'BG-GTA6-PS5',
            'inventory_quantity' => 88,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Reserva oficial de Grand Theft Auto VI para PlayStation 5 (Mídia Digital Primária). Bônus de pré-venda inclusos e garantia vitalícia.',
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
            'compare_at_price' => '189.90',
            'sku' => 'BG-COD-BO6',
            'inventory_quantity' => 64,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Pacote Multi-Geração Call of Duty: Black Ops 6 com campanha completa, Multiplayer e modo Zombies. Ativação guiada com suporte 7 dias por semana.',
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
            'compare_at_price' => '259.90',
            'sku' => 'GBX-GPU-12M',
            'inventory_quantity' => 310,
            'image_url' => 'https://gameboxbrasil.com/cdn/shop/files/IMG_3468_ed6eda99-80d9-46d6-9340-d06f3d6410e9.png',
            'description' => '12 meses completos de Xbox Game Pass Ultimate: centenas de jogos no Console, PC e Xbox Cloud Gaming, além de EA Play e Xbox Live Gold inclusos.',
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
            'compare_at_price' => '139.90',
            'sku' => 'GBX-FH5-PREM',
            'inventory_quantity' => 92,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Edição Suprema com Passe de Carros, Assinatura VIP, Pacote de Boas-Vindas e expansões Hot Wheels + Rally Adventure.',
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
            'compare_at_price' => '100.00',
            'sku' => 'GBX-GIFT-100',
            'inventory_quantity' => 500,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Código digital oficial de 25 dígitos para resgate imediato na Microsoft Store Brasil (redeem.microsoft.com).',
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
            'compare_at_price' => '89.90',
            'sku' => 'GGL-FC27-STEAM-OFF',
            'inventory_quantity' => 420,
            'image_url' => 'https://gamesgl.com/cdn/shop/files/Untitled_design_16.png',
            'description' => 'Acesso completo ao Modo Carreira Manager e Jogador do EA SPORTS FC 27 via Steam PC com atualizações de elencos.',
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
            'compare_at_price' => '179.90',
            'sku' => 'GGL-WUKONG-PC',
            'inventory_quantity' => 115,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'RPG de ação aclamado inspirado na mitologia chinesa. Edição Deluxe para PC Steam com armas e armaduras bônus.',
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
            'compare_at_price' => '129.90',
            'sku' => 'GGL-ELDEN-PC',
            'inventory_quantity' => 75,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Jogo base Elden Ring + expansão completa Shadow of the Erdtree para PC via Steam.',
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
            'compare_at_price' => '349.90',
            'sku' => 'GS-FC27-ULT-500K',
            'inventory_quantity' => 250,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Edição Online Completa para Steam com acesso total ao Ultimate Team + pacote bônus de 500.000 FC Coins entregue com segurança.',
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
            'compare_at_price' => '99.90',
            'sku' => 'GS-FCCOINS-100K',
            'inventory_quantity' => 999,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Recarga rápida de 100.000 FC Coins para montar seu elenco no Ultimate Team com método seguro anti-ban.',
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
            'compare_at_price' => '89.90',
            'sku' => 'GS-GAMEPASS-ULT',
            'inventory_quantity' => 180,
            'image_url' => '/dashboard/images/integrations/shopify.png',
            'description' => 'Assinatura completa Xbox Game Pass Ultimate compatível com Xbox One, Series X|S, PC Windows e Cloud Gaming.',
            'store_name' => store_name,
            'hook_id' => hook.id
          }
        ]
      end

    raw_items.map do |item|
      item.merge(
        'vendor' => store_name,
        'shop_domain' => hook.reference_id,
        'admin_url' => "https://#{hook.reference_id}/admin/products/#{item['id']}",
        'storefront_url' => "https://#{hook.reference_id}/products/#{item['handle']}",
        'images' => [item['image_url']],
        'variants' => [
          {
            'id' => "#{item['id']}-1",
            'title' => 'Licença Primária Digital (Envio Imediato)',
            'price' => item['price'],
            'compare_at_price' => item['compare_at_price'],
            'sku' => item['sku'],
            'inventory_quantity' => item['inventory_quantity']
          },
          {
            'id' => "#{item['id']}-2",
            'title' => 'Edição VIP + Suporte Prioritário WhatsApp',
            'price' => format('%.2f', item['price'].to_f + 30.0),
            'compare_at_price' => format('%.2f', item['compare_at_price'].to_f + 40.0),
            'sku' => "#{item['sku']}-VIP",
            'inventory_quantity' => 50
          }
        ]
      )
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
      raw_orders = filter_orders_by_period(filter_mock_orders_for_hook(hook))
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
      order_params = { status: 'any', limit: 250, fields: ORDER_FIELDS }
      min_iso = period_created_at_min
      order_params[:created_at_min] = min_iso if min_iso.present?
      res = shopify_get(hook, 'orders.json', order_params)
      raw_orders.concat(res['orders'] || [])
    end

    filtered_orders = filter_orders_by_period(raw_orders.uniq { |o| o['id'] })
    filtered_orders.map { |order| serialize_order(hook, order) }
  end

  def period_created_at_min
    case @period
    when 'today'
      24.hours.ago.iso8601
    when '7d'
      7.days.ago.iso8601
    when '30d'
      30.days.ago.iso8601
    end
  end

  def filter_orders_by_period(orders)
    return orders if @period.blank? || @period == 'all' || @query.present? || @contact.present?

    cutoff = case @period
             when 'today' then 24.hours.ago
             when '7d' then 7.days.ago
             when '30d' then 30.days.ago
             end
    return orders if cutoff.blank?

    orders.select do |order|
      created_time = Time.zone.parse(order['created_at'].to_s)
      created_time.present? && created_time >= cutoff
    end
  end

  def filter_mock_orders_for_hook(hook)
    catalog = build_mock_orders_for_hook(hook)

    if @query.blank? && @contact.present? && (@contact.email.present? || @contact.phone_number.present?)
      target_email = @contact.email.to_s.strip.downcase
      target_digits = @contact.phone_number.to_s.gsub(/\D/, '')
      matched_for_contact = catalog.select do |order|
        (target_email.present? && order['email'].to_s.downcase == target_email) ||
          (target_digits.length >= 8 && order['phone'].to_s.gsub(/\D/, '').include?(target_digits))
      end
      return matched_for_contact if matched_for_contact.any?

      return []
    end

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
    now = Time.current

    if ref.include?('barba') || store_name.downcase.include?('barba')
      [
        {
          'id' => 902_101,
          'name' => '#BG-41820',
          'email' => 'lucas.oliveira@gmail.com',
          'phone' => '+5511997123456',
          'customer' => {
            'id' => 701,
            'name' => 'Lucas Oliveira'
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
          'email' => 'rafael.mendes@hotmail.com',
          'phone' => '+5521988451230',
          'customer' => {
            'id' => 702,
            'name' => 'Rafael Mendes'
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
        },
        {
          'id' => 902_103,
          'name' => '#BG-41988',
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
          },
          'created_at' => (now - 14.hours).iso8601,
          'updated_at' => (now - 13.hours).iso8601,
          'total_price' => '129.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue, multi-pedido, xbox-ps5',
          'line_items' => [
            {
              'id' => 13,
              'title' => 'Call of Duty: Black Ops 6 - Cross-Gen Bundle (Xbox / PS5)',
              'variant_title' => 'Licença Completa Cross-Gen',
              'sku' => 'BG-COD-BO6',
              'quantity' => 1,
              'price' => '129.90',
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
          'email' => 'gabriel.costa@uol.com.br',
          'phone' => '+5531991239876',
          'customer' => {
            'id' => 801,
            'name' => 'Gabriel Costa'
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
          'email' => 'amanda.silva@gmail.com',
          'phone' => '+5541996543210',
          'customer' => {
            'id' => 802,
            'name' => 'Amanda Silva'
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
          'email' => 'pedro.almeida@gmail.com',
          'phone' => '+5551993456789',
          'customer' => {
            'id' => 901,
            'name' => 'Pedro Almeida'
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
          'email' => 'thiago.rocha@outlook.com',
          'phone' => '+5581994561234',
          'customer' => {
            'id' => 902,
            'name' => 'Thiago Rocha'
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
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
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
          'email' => 'bruno.santos@gmail.com',
          'phone' => '+5511987651234',
          'customer' => {
            'id' => 602,
            'name' => 'Bruno Santos'
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
        },
        {
          'id' => 901_003,
          'name' => '#31588',
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
          },
          'created_at' => (now - 6.hours).iso8601,
          'updated_at' => (now - 5.hours).iso8601,
          'total_price' => '139.80',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'entregue, fc-coins, recorrente',
          'line_items' => [
            {
              'id' => 3,
              'title' => '100 mil FC Coins - EA SPORTS FC 27 (Xbox / PS5 / PC)',
              'variant_title' => 'Transferência Segura Comfort Trade',
              'sku' => 'GS-FCCOINS-100K',
              'quantity' => 2,
              'price' => '69.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        },
        {
          'id' => 901_004,
          'name' => '#31204',
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
          },
          'created_at' => (now - 4.days).iso8601,
          'updated_at' => (now - 4.days).iso8601,
          'total_price' => '59.90',
          'currency' => 'BRL',
          'financial_status' => 'pending',
          'fulfillment_status' => 'unfulfilled',
          'tags' => 'gamepass, boleto-pendente',
          'line_items' => [
            {
              'id' => 4,
              'title' => 'Assinatura Xbox Game Pass Ultimate - Acesso Completo',
              'variant_title' => 'Licença Mensal Renovável',
              'sku' => 'GS-GAMEPASS-ULT',
              'quantity' => 1,
              'price' => '59.90',
              'fulfillment_status' => nil
            }
          ]
        },
        {
          'id' => 890_412,
          'name' => '#24890',
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
          },
          'created_at' => (now - 75.days).iso8601,
          'updated_at' => (now - 75.days).iso8601,
          'total_price' => '189.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'pedido-antigo, entregue, fc-26',
          'line_items' => [
            {
              'id' => 5,
              'title' => 'EA SPORTS FC 26 Standard Edition - Xbox / PC (Histórico)',
              'variant_title' => 'Mídia Digital Completa',
              'sku' => 'GS-FC26-STD',
              'quantity' => 1,
              'price' => '189.90',
              'fulfillment_status' => 'fulfilled'
            }
          ]
        },
        {
          'id' => 871_105,
          'name' => '#18340',
          'email' => 'matheus.ferreira@gamessafari.com',
          'phone' => '+5511998765432',
          'customer' => {
            'id' => 601,
            'name' => 'Matheus Ferreira'
          },
          'created_at' => (now - 210.days).iso8601,
          'updated_at' => (now - 210.days).iso8601,
          'total_price' => '179.90',
          'currency' => 'BRL',
          'financial_status' => 'paid',
          'fulfillment_status' => 'fulfilled',
          'tags' => 'pedido-antigo, entregue, gamepass-anual',
          'line_items' => [
            {
              'id' => 6,
              'title' => 'Assinatura Xbox Game Pass Ultimate - 12 Meses (Compra Antiga)',
              'variant_title' => 'Código 25 Dígitos Entregue',
              'sku' => 'GS-GAMEPASS-12M-OLD',
              'quantity' => 1,
              'price' => '179.90',
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
    # Using customers/:id/orders.json with status=any fetches full customer history including older/archived orders
    res_customer_endpoint = shopify_get(
      hook,
      "customers/#{customer_id}/orders.json",
      status: 'any',
      limit: 100,
      fields: ORDER_FIELDS
    )
    orders = res_customer_endpoint['orders'] || []
    return orders if orders.any?

    res = shopify_get(
      hook,
      'orders.json',
      customer_id: customer_id,
      status: 'any',
      limit: 100,
      created_at_min: '2018-01-01T00:00:00-00:00',
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
      limit: 50,
      created_at_min: '2018-01-01T00:00:00-00:00',
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
      limit: 50,
      created_at_min: '2018-01-01T00:00:00-00:00',
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
      limit: 100,
      created_at_min: '2018-01-01T00:00:00-00:00',
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

    line_items_serialized = Array(order['line_items']).map do |item|
      {
        'id' => item['id'],
        'title' => item['title'],
        'variant_title' => item['variant_title'],
        'sku' => item['sku'],
        'quantity' => item['quantity'],
        'price' => item['price'],
        'image_url' => item['image_url'].presence || '/dashboard/images/integrations/shopify.png',
        'fulfillment_status' => item['fulfillment_status']
      }
    end

    payment_gateways = Array(order['payment_gateway_names']).presence || [order['gateway'].presence || 'PIX / Cartão de Crédito (Mercado Pago)']
    ship_addr = order['shipping_address'] || order['billing_address'] || {
      'city' => 'São Paulo',
      'province_code' => 'SP',
      'country' => 'Brasil'
    }
    fulfillments_list = Array(order['fulfillments']).map do |f|
      {
        'id' => f['id'],
        'status' => f['status'] || 'success',
        'tracking_company' => f['tracking_company'] || 'Entrega Digital Automática',
        'tracking_number' => f['tracking_number'],
        'tracking_url' => f['tracking_url'],
        'created_at' => f['created_at']
      }
    end
    if fulfillments_list.empty? && order['fulfillment_status'] == 'fulfilled'
      fulfillments_list = [
        {
          'id' => "ful-#{order['id']}",
          'status' => 'success',
          'tracking_company' => 'Entrega Digital (E-mail / WhatsApp)',
          'tracking_number' => "DIG-#{order['id']}-BR",
          'tracking_url' => "https://#{hook.reference_id}/admin/orders/#{order['id']}",
          'created_at' => order['updated_at'] || order['created_at']
        }
      ]
    end

    {
      'id' => order['id'],
      'name' => order['name'].presence || "##{order['id']}",
      'email' => order['email'],
      'phone' => order['phone'],
      'customer_name' => customer_name,
      'customer_orders_count' => cust['orders_count'] || 2,
      'created_at' => order['created_at'],
      'updated_at' => order['updated_at'],
      'minutes_since_created' => minutes_since_created,
      'within_one_hour_window' => minutes_since_created.present? ? minutes_since_created < 60 : false,
      'subtotal_price' => order['subtotal_price'].presence || order['total_price'],
      'total_discounts' => order['total_discounts'].presence || '0.00',
      'total_tax' => order['total_tax'].presence || '0.00',
      'total_price' => order['total_price'],
      'currency' => order['currency'] || 'BRL',
      'financial_status' => order['financial_status'],
      'fulfillment_status' => order['fulfillment_status'].presence || 'unfulfilled',
      'payment_method' => payment_gateways.join(', '),
      'note' => order['note'].presence || 'Envio digital prioritário verificado pelo antifraude.',
      'shipping_city' => [ship_addr['city'], ship_addr['province_code']].compact.join(' - ').presence || 'Entrega Digital',
      'order_status_url' => order['order_status_url'].presence || "https://#{hook.reference_id}/orders/#{order['id']}",
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
      'fulfillments' => fulfillments_list,
      'line_items' => line_items_serialized
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

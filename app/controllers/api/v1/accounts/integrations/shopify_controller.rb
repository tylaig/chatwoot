class Api::V1::Accounts::Integrations::ShopifyController < Api::V1::Accounts::Integrations::BaseController
  include Shopify::IntegrationHelper
  before_action :check_authorization, only: [:connect_token, :update_hook, :destroy]
  before_action :fetch_hook, only: [:update_hook, :destroy]
  before_action :validate_orders_request, only: [:orders]

  def auth
    shop_domain = Shopify::ShopDomain.normalize(params[:shop_domain])
    return render json: { error: 'Shop domain is required' }, status: :unprocessable_entity if shop_domain.blank?

    state = generate_shopify_token(Current.account.id)

    auth_url = "https://#{shop_domain}/admin/oauth/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      scope: REQUIRED_SCOPES.join(','),
      redirect_uri: redirect_uri,
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def connect_token
    shop_domain = Shopify::ShopDomain.normalize(params[:shop_domain])
    access_token = params[:access_token].to_s.strip
    store_name = params[:store_name].to_s.strip
    inbox_ids = Array(params[:inbox_ids]).map(&:to_i).reject(&:zero?).uniq

    shop_info = Shopify::MultiStoreOrderFinderService.verify_connection!(
      shop_domain: shop_domain,
      access_token: access_token
    )

    hook = Current.account.hooks.find_or_initialize_by(
      app_id: 'shopify',
      reference_id: shop_domain
    )
    hook.access_token = access_token
    hook.status = :enabled
    hook.settings = (hook.settings || {}).merge(
      'store_name' => store_name.presence || shop_info['name'].presence || shop_domain,
      'inbox_ids' => inbox_ids,
      'auth_mode' => 'access_token',
      'shop_name' => shop_info['name'],
      'shop_email' => shop_info['email'],
      'domain' => shop_info['domain']
    )
    hook.save!

    render json: {
      hook: {
        id: hook.id,
        app_id: hook.app_id,
        reference_id: hook.reference_id,
        status: hook.enabled?,
        settings: hook.settings
      }
    }, status: :ok
  rescue ArgumentError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_hook
    store_name = params[:store_name].to_s.strip
    inbox_ids = Array(params[:inbox_ids]).map(&:to_i).reject(&:zero?).uniq
    access_token = params[:access_token].to_s.strip

    if access_token.present?
      shop_info = Shopify::MultiStoreOrderFinderService.verify_connection!(
        shop_domain: @hook.reference_id,
        access_token: access_token
      )
      @hook.access_token = access_token
      @hook.settings = (@hook.settings || {}).merge(
        'shop_name' => shop_info['name'],
        'shop_email' => shop_info['email'],
        'domain' => shop_info['domain']
      )
    end

    updated_settings = (@hook.settings || {}).dup
    updated_settings['store_name'] = store_name if store_name.present?
    updated_settings['inbox_ids'] = inbox_ids if params.key?(:inbox_ids)
    @hook.settings = updated_settings
    @hook.save!

    render json: {
      hook: {
        id: @hook.id,
        app_id: @hook.app_id,
        reference_id: @hook.reference_id,
        status: @hook.enabled?,
        settings: @hook.settings
      }
    }, status: :ok
  rescue ArgumentError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def orders
    query_str = params[:query].to_s.strip
    orders_list = Shopify::MultiStoreOrderFinderService.new(
      account: Current.account,
      contact: contact,
      query: query_str,
      inbox_id: params[:inbox_id],
      hook_id: params[:hook_id]
    ).perform

    sync_contact_email_from_orders(orders_list, query_str) if ActiveModel::Type::Boolean.new.cast(params[:sync_contact_email])

    render json: { orders: orders_list }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/shopify/callback"
  end

  def contact
    return nil if params[:contact_id].blank?

    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    scope = Current.account.hooks.where(app_id: 'shopify')
    @hook = params[:hook_id].present? ? scope.find(params[:hook_id]) : scope.first!
  end

  def validate_orders_request
    return if params[:query].to_s.strip.present?
    return if contact.present? && (contact.email.present? || contact.phone_number.present?)

    render json: { orders: [] }, status: :ok
  end

  def sync_contact_email_from_orders(orders_list, query_str)
    return if contact.blank? || contact.email.present?

    candidate_email = if query_str.include?('@')
                        query_str.downcase
                      else
                        orders_list.find { |o| o['email'].present? }&.dig('email')&.downcase
                      end
    return if candidate_email.blank?

    contact.update(email: candidate_email)
  rescue StandardError => e
    Rails.logger.warn("[ShopifyController] Could not auto-sync contact email: #{e.message}")
  end
end

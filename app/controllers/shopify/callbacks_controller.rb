class Shopify::CallbacksController < ApplicationController
  include Shopify::IntegrationHelper

  def show
    verify_account!

    @response = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: '/shopify/callback'
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("Shopify callback error: #{e.message}")
    redirect_to "#{redirect_uri}?error=true"
  end

  private

  def verify_account!
    if params[:state].to_s.start_with?('hook_')
      _, account_part, _hook_part = params[:state].to_s.split('_')
      @account_id = account_part.to_i
    else
      @account_id = verify_shopify_token(params[:state])
    end
    raise StandardError, 'Invalid state parameter' if account.blank?
  end

  def handle_response
    account.with_lock do
      normalized_shop = Shopify::ShopDomain.normalize(params[:shop])
      hook = account.hooks.find_or_initialize_by(app_id: 'shopify', reference_id: normalized_shop)
      existing_settings = (hook.settings || {}).dup
      hook.update!(
        access_token: parsed_body['access_token'],
        status: 'enabled',
        settings: existing_settings.merge(
          'scope' => parsed_body['scope'],
          'auth_mode' => 'access_token',
          'connection_status' => 'connected',
          'connected_at' => Time.current.utc.iso8601(6),
          'last_tested_at' => Time.current.utc.iso8601,
          'installation_id' => existing_settings['installation_id'] || SecureRandom.uuid
        )
      )
      begin
        products = Shopify::MultiStoreOrderFinderService.fetch_products_for_hook!(hook)
        hook.update!(settings: hook.settings.merge('products' => products, 'products_count' => products.size, 'last_synced_at' => Time.current.utc.iso8601))
      rescue StandardError => e
        Rails.logger.warn("Shopify initial sync warning: #{e.message}")
      end
    end

    redirect_to shopify_integration_url
  end

  def parsed_body
    @parsed_body ||= @response.response.parsed
  end

  def hook_for_shop
    return @hook_for_shop if defined?(@hook_for_shop)

    normalized_shop = Shopify::ShopDomain.normalize(params[:shop])
    @hook_for_shop = account&.hooks&.find_by(app_id: 'shopify', reference_id: normalized_shop)
  end

  def oauth_client
    effective_client_id = hook_for_shop&.settings&.dig('client_id').presence || client_id
    effective_client_secret = hook_for_shop&.settings&.dig('client_secret').presence || client_secret
    OAuth2::Client.new(
      effective_client_id,
      effective_client_secret,
      {
        site: "https://#{params[:shop]}",
        authorize_url: '/admin/oauth/authorize',
        token_url: '/admin/oauth/access_token'
      }
    )
  end

  def account
    @account ||= Account.find(@account_id)
  end

  def account_id
    @account_id ||= params[:state].split('_').first
  end

  def shopify_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{account.id}/settings/integrations/shopify"
  end

  def redirect_uri
    return shopify_integration_url if account

    ENV.fetch('FRONTEND_URL', nil)
  end
end

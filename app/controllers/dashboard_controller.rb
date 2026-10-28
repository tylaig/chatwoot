class DashboardController < ActionController::Base
  include SwitchLocale
  include PortalHomeData

  GLOBAL_CONFIG_KEYS = %w[
    LOGO
    LOGO_DARK
    LOGO_THUMBNAIL
    INSTALLATION_NAME
    WIDGET_BRAND_URL
    TERMS_URL
    BRAND_URL
    BRAND_NAME
    BRAND_COLOR
    PRIVACY_URL
    DISPLAY_MANIFEST
    CREATE_NEW_ACCOUNT_FROM_DASHBOARD
    CHATWOOT_INBOX_TOKEN
    API_CHANNEL_NAME
    API_CHANNEL_THUMBNAIL
    CLOUD_ANALYTICS_TOKEN
    DIRECT_UPLOADS_ENABLED
    MAXIMUM_FILE_UPLOAD_SIZE
    HCAPTCHA_SITE_KEY
    LOGOUT_REDIRECT_LINK
    DISABLE_USER_PROFILE_UPDATE
    DISABLE_META_INBOX_CREATION
    DISABLE_META_MESSAGE_SENDING
    DEPLOYMENT_ENV
    INSTALLATION_PRICING_PLAN
  ].freeze

  before_action :set_application_pack
  before_action :set_global_config
  before_action :set_dashboard_scripts
  around_action :switch_locale
  before_action :ensure_installation_onboarding, only: [:index]
  before_action :render_hc_if_custom_domain, only: [:index]
  before_action :ensure_html_format
  layout 'vueapp'

  def index
    return if handle_root_redirect
  end

  private

  def handle_root_redirect
    return false unless request.path == '/'

    host = request.host.to_s.downcase
    if host.start_with?('meet.')
      redirect_to '/msc-demo', status: :found
      return true
    elsif host.start_with?('agenda.')
      redirect_to '/samuel-vicente', status: :found
      return true
    end

    user = resolve_cookie_authenticated_user
    if user
      account_id = user.account_users.order(active_at: :desc).pick(:account_id) || user.accounts.pick(:id) || 1
      redirect_to "/app/accounts/#{account_id}/dashboard", status: :found
    else
      redirect_to '/lp', status: :found
    end
    true
  end

  def resolve_cookie_authenticated_user
    raw_cookie = cookies['cw_d_session_info']
    return nil if raw_cookie.blank?

    parsed = JSON.parse(URI.decode_www_form_component(raw_cookie)) rescue nil
    parsed ||= JSON.parse(raw_cookie) rescue nil
    return nil unless parsed.is_a?(Hash)

    uid = parsed['uid']
    token = parsed['access-token']
    client = parsed['client']
    return nil if uid.blank? || token.blank? || client.blank?

    user = User.find_by(uid: uid) || User.find_by(email: uid)
    return nil unless user&.valid_token?(token, client)

    user
  rescue StandardError
    nil
  end

  def ensure_html_format
    render json: { error: 'Please use API routes instead of dashboard routes for JSON requests' }, status: :not_acceptable if request.format.json?
  end

  def set_global_config
    @global_config = GlobalConfig.get(*GLOBAL_CONFIG_KEYS).merge(app_config)
  end

  def set_dashboard_scripts
    @dashboard_scripts = sensitive_path? ? nil : GlobalConfig.get_value('DASHBOARD_SCRIPTS')
  end

  def ensure_installation_onboarding
    redirect_to '/installation/onboarding' if ::Redis::Alfred.get(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
  end

  def render_hc_if_custom_domain
    domain = request.host
    return if domain == URI.parse(ENV.fetch('FRONTEND_URL', '')).host || domain.to_s.end_with?('.meusuper.app')

    @portal = Portal.find_by(custom_domain: domain)
    return unless @portal

    @locale = @portal.default_locale
    request.variant = :documentation if @portal.layout == 'documentation'
    load_home_data
    render 'public/api/v1/portals/show', layout: 'portal', portal: @portal and return
  end

  def app_config
    {
      APP_VERSION: Chatwoot.config[:version],
      VAPID_PUBLIC_KEY: VapidService.public_key,
      ENABLE_ACCOUNT_SIGNUP: GlobalConfigService.load('ENABLE_ACCOUNT_SIGNUP', 'false'),
      FB_APP_ID: GlobalConfigService.load('FB_APP_ID', ''),
      INSTAGRAM_APP_ID: GlobalConfigService.load('INSTAGRAM_APP_ID', ''),
      TIKTOK_APP_ID: GlobalConfigService.load('TIKTOK_APP_ID', ''),
      FACEBOOK_API_VERSION: GlobalConfigService.load('FACEBOOK_API_VERSION', 'v18.0'),
      WHATSAPP_APP_ID: GlobalConfigService.load('WHATSAPP_APP_ID', ''),
      WHATSAPP_CONFIGURATION_ID: GlobalConfigService.load('WHATSAPP_CONFIGURATION_ID', ''),
      IS_ENTERPRISE: ChatwootApp.enterprise?,
      BAILEYS_WHATSAPP_GROUPS_ENABLED: Whatsapp::Providers::WhatsappBaileysService.groups_enabled?,
      AZURE_APP_ID: GlobalConfigService.load('AZURE_APP_ID', ''),
      GIT_SHA: GIT_HASH,
      ALLOWED_LOGIN_METHODS: allowed_login_methods,
      ACTIVE_PLATFORM_BANNERS: active_platform_banners
    }
  end

  def active_platform_banners
    return [] unless ChatwootApp.chatwoot_cloud?

    PlatformBanner.active.order(created_at: :desc).as_json(only: %i[id banner_message banner_type updated_at])
  end

  def allowed_login_methods
    methods = ['email']
    methods << 'google_oauth' if GlobalConfigService.load('ENABLE_GOOGLE_OAUTH_LOGIN', 'true').to_s != 'false'
    methods << 'saml' if ChatwootHub.pricing_plan != 'community' && GlobalConfigService.load('ENABLE_SAML_SSO_LOGIN', 'true').to_s != 'false'
    methods
  end

  def set_application_pack
    @application_pack = if request.path.include?('/auth') || request.path.include?('/login')
                          'v3app'
                        else
                          'dashboard'
                        end
  end

  def sensitive_path?
    # dont load dashboard scripts on sensitive paths like password reset
    sensitive_paths = [edit_user_password_path].freeze

    # remove app prefix
    current_path = request.path.gsub(%r{^/app}, '')

    sensitive_paths.include?(current_path)
  end
end

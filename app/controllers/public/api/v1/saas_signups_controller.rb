# frozen_string_literal: true

class Public::Api::V1::SaasSignupsController < PublicController
  before_action :ensure_signup_allowed

  rescue_from CustomExceptions::Account::InvalidEmail,
              CustomExceptions::Account::InvalidParams,
              CustomExceptions::Account::UserExists,
              CustomExceptions::Account::UserErrors,
              with: :render_error_response

  def create
    validate_required_params!

    plan_tier = EliteLicenseEngine.resolve_self_service_tier(signup_params[:plan_tier])
    locale = signup_params[:locale].presence || 'pt_BR'

    @user, @account = AccountBuilder.new(
      account_name: signup_params[:account_name],
      user_full_name: signup_params[:user_full_name],
      email: signup_params[:email].to_s.strip.downcase,
      user_password: signup_params[:password],
      locale: locale,
      confirmed: true,
      plan_tier: plan_tier
    ).perform

    persist_signup_metadata!(plan_tier)
    enqueue_branding_enrichment

    token_data = @user.create_new_auth_token
    emit_auth_headers(token_data)

    tier_info = EliteLicenseEngine.account_tier(@account)
    render json: {
      ok: true,
      account_id: @account.id,
      account_name: @account.name,
      plan_tier: tier_info[:key],
      plan_name: tier_info[:name],
      price_label: tier_info[:price_label],
      limits: {
        agents: tier_info[:max_agents],
        inboxes: tier_info[:max_inboxes],
        captain_responses: tier_info[:captain_responses],
        captain_documents: tier_info[:captain_documents]
      },
      redirect_url: "/app/accounts/#{@account.id}/dashboard",
      auth_headers: {
        'access-token' => token_data['access-token'],
        'token-type' => 'Bearer',
        'client' => token_data['client'],
        'expiry' => token_data['expiry'],
        'uid' => token_data['uid']
      },
      user: {
        id: @user.id,
        name: @user.name,
        email: @user.email,
        uid: @user.uid,
        account_id: @account.id
      }
    }, status: :created
  end

  private

  def ensure_signup_allowed
    return if GlobalConfigService.load('MSC_SELF_SERVICE_SIGNUP_ENABLED', 'true').to_s != 'false'
    return if GlobalConfigService.account_signup_enabled?

    render json: { error: 'Self-service signup is currently disabled' }, status: :forbidden
  end

  def validate_required_params!
    if signup_params[:account_name].blank? ||
       signup_params[:user_full_name].blank? ||
       signup_params[:email].blank? ||
       signup_params[:password].blank?
      raise CustomExceptions::Account::InvalidParams.new({})
    end
  end

  def persist_signup_metadata!(plan_tier)
    custom_attrs = (@account.custom_attributes || {}).dup
    custom_attrs['plan_name'] = plan_tier
    custom_attrs['subscription_status'] = 'trialing'
    custom_attrs['trial_ends_at'] = 14.days.from_now.iso8601
    custom_attrs['whatsapp_phone'] = signup_params[:whatsapp] if signup_params[:whatsapp].present?
    custom_attrs['desired_domain'] = signup_params[:domain] if signup_params[:domain].present?
    custom_attrs['signup_source'] = 'self_service_lp'
    @account.update!(custom_attributes: custom_attrs)
  end

  def enqueue_branding_enrichment
    email = @user&.email
    return if email.blank?

    Account::BrandingEnrichmentJob.perform_later(@account.id, email)
    Redis::Alfred.set(format(Redis::Alfred::ACCOUNT_ONBOARDING_ENRICHMENT, account_id: @account.id), '1', ex: 30)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  def emit_auth_headers(token_data)
    response.headers[DeviseTokenAuth.headers_names[:'access-token']] = token_data['access-token']
    response.headers[DeviseTokenAuth.headers_names[:'token-type']]   = 'Bearer'
    response.headers[DeviseTokenAuth.headers_names[:client]]         = token_data['client']
    response.headers[DeviseTokenAuth.headers_names[:expiry]]         = token_data['expiry']
    response.headers[DeviseTokenAuth.headers_names[:uid]]            = token_data['uid']
  end

  def signup_params
    params.permit(
      :account_name,
      :user_full_name,
      :email,
      :password,
      :plan_tier,
      :whatsapp,
      :domain,
      :locale
    )
  end
end

class Enterprise::Billing::ReconcilePlanFeaturesService
  CLOUD_PLANS_CONFIG = 'CHATWOOT_CLOUD_PLANS'.freeze
  SHOPIFY_MANAGED_FEATURES = 'shopify_managed_features'.freeze

  # Plan hierarchy: Hacker (default) -> Startups -> Business -> Enterprise
  # Each higher tier includes all features from the lower tiers
  STARTUP_PLAN_FEATURES = %w[
    inbound_emails
    help_center
    campaigns
    team_management
    channel_facebook
    channel_email
    channel_instagram
    captain_integration
    captain_document_auto_sync
    advanced_search_indexing
    advanced_search
    linear_integration
    channel_voice
    whatsapp_embedded_signup_inbox_creation
    api_and_webhooks
    data_import
  ].freeze

  BUSINESS_PLAN_FEATURES = %w[
    sla
    custom_roles
    csat_review_notes
    conversation_required_attributes
    advanced_assignment
    custom_tools
    companies
  ].freeze
  ENTERPRISE_PLAN_FEATURES = %w[audit_logs disable_branding saml].freeze
  PREMIUM_PLAN_FEATURES = (STARTUP_PLAN_FEATURES + BUSINESS_PLAN_FEATURES + ENTERPRISE_PLAN_FEATURES).freeze
  SHOPIFY_BASE_MANAGED_FEATURES = (PREMIUM_PLAN_FEATURES + %w[channel_tiktok captain_integration_v2]).freeze

  pattr_initialize [:account!, { shopify_lifecycle_cleanup: false }]

  def perform
    return if shopify_billing? && !shopify_lifecycle_cleanup && !Shopify::FeatureGate.enabled?(account: account)

    if elite_tier_managed?
      EliteLicenseEngine.apply_tier_to_account!(account, elite_tier_key, custom_limits: elite_custom_limits, sync_sidebar: false)
      return
    end

    account.disable_features(*managed_plan_features)
    account.disable_features('captain_integration_v2') if default_plan?
    account.enable_features(*current_plan_features)
    account.enable_features('captain_integration_v2') if captain_v2_enabled_by_default?
    account.enable_features(*manually_managed_features)
    update_shopify_managed_features
    account.save!
  end

  private

  def current_plan_features
    return [] if default_plan?
    return Enterprise::Billing::PlanConfiguration.current_plan!(account).fetch('features') if shopify_billing?

    case account.custom_attributes['plan_name']
    when 'Startups' then STARTUP_PLAN_FEATURES
    when 'Business' then STARTUP_PLAN_FEATURES + BUSINESS_PLAN_FEATURES
    when 'Enterprise' then PREMIUM_PLAN_FEATURES
    else []
    end
  end

  def default_plan?
    return account.custom_attributes['plan_name'].blank? if shopify_billing?

    default_plan_name = cloud_plans.first&.dig('name')
    return false if default_plan_name.blank?

    plan_name = account.custom_attributes['plan_name']
    plan_name.blank? || plan_name == default_plan_name
  end

  def cloud_plans
    @cloud_plans ||= InstallationConfig.find_by(name: CLOUD_PLANS_CONFIG)&.value || []
  end

  def managed_plan_features
    return PREMIUM_PLAN_FEATURES unless shopify_billing?

    (SHOPIFY_BASE_MANAGED_FEATURES + previously_managed_shopify_features + current_shopify_catalog_features).uniq
  end

  def previously_managed_shopify_features
    Array(account.internal_attributes[SHOPIFY_MANAGED_FEATURES])
  end

  def current_shopify_catalog_features
    return @current_shopify_catalog_features if defined?(@current_shopify_catalog_features)

    plans = Enterprise::Billing::PlanConfiguration.plans_for(account)
    @current_shopify_catalog_features = plans.flat_map { |plan| plan.fetch('features') }.uniq
  end

  def update_shopify_managed_features
    return unless shopify_billing?

    account.internal_attributes[SHOPIFY_MANAGED_FEATURES] = current_shopify_catalog_features
  end

  def shopify_billing?
    account.billing_provider == 'shopify'
  end

  def manually_managed_features
    @manually_managed_features ||= Internal::Accounts::InternalAttributesService.new(account).manually_managed_features
  end

  def captain_v2_enabled_by_default?
    !shopify_billing? && !default_plan?
  end

  def elite_tier_managed?
    return false unless defined?(EliteLicenseEngine)
    return false if shopify_billing?

    plan_name = account.custom_attributes['plan_name'].to_s
    return true if EliteLicenseEngine::TIERS.key?(plan_name.downcase)

    # Only delegate to EliteLicenseEngine when no Chatwoot Cloud catalog plan matches
    cloud_plan_names = cloud_plans.filter_map { |p| p['name'] }
    return false if cloud_plan_names.any? { |name| name.casecmp?(plan_name) }

    account.settings&.dig('elite_plan_tier').present? || EliteLicenseEngine.resolve_billing_tier_key(plan_name).present?
  end

  def elite_tier_key
    EliteLicenseEngine.resolve_billing_tier_key(account.custom_attributes['plan_name']) ||
      account.settings&.dig('elite_plan_tier') ||
      'starter'
  end

  def elite_custom_limits
    qty = account.custom_attributes['subscribed_quantity'].to_i
    qty.positive? ? { agents: qty } : {}
  end
end

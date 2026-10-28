# frozen_string_literal: true

require 'openssl'
require 'securerandom'

class EliteLicenseEngine
  PLATFORM_NAME = 'Meu Super Chat Elite Label'
  PLATFORM_HEADER = 'MeuSuperChat-Elite'

  ALL_SIDEBAR_ITEMS = %w[
    scheduled_messages
    calendar_appointments
    conversation_actions
    shopify_orders
    macros
    conversation_info
    contact_attributes
    contact_notes
    shared_files
    previous_conversation
    conversation_participants
    linear_issues
  ].freeze

  STARTER_FEATURES = %w[
    inbound_emails
    channel_email
    channel_web_widget
    channel_facebook
    channel_instagram
    channel_telegram
    help_center
    macros
    automations
    canned_responses
    labels
    custom_attributes
    team_management
    voice_recorder
  ].freeze

  PRO_FEATURES = (STARTER_FEATURES + %w[
    campaigns
    reports
    integrations
    whatsapp_campaign
    crm_sales_pipeline
  ]).uniq.freeze

  BUSINESS_FEATURES = (PRO_FEATURES + %w[
    captain_integration
    captain_integration_v2
    sla
    custom_roles
    audit_logs
    agent_capacity
    shopify_integration
    linear_integration
  ]).uniq.freeze

  ELITE_WHITELABEL_FEATURES = (BUSINESS_FEATURES + %w[
    disable_branding
    saml
    companies
    channel_voice
  ]).uniq.freeze

  TIERS = {
    'starter' => {
      key: 'starter',
      name: 'Starter SaaS',
      badge: 'STARTER',
      price_label: 'R$ 197/mês',
      description: 'Ideal para pequenas operações iniciando atendimento centralizado.',
      max_agents: 3,
      max_inboxes: 2,
      max_accounts: 1,
      whitelabel_enabled: false,
      captain_ai_enabled: false,
      custom_branding_enabled: false,
      features: STARTER_FEATURES,
      sidebar_items: %w[
        conversation_info
        conversation_actions
        contact_attributes
        contact_notes
        shared_files
        previous_conversation
      ]
    },
    'pro' => {
      key: 'pro',
      name: 'Pro Growth',
      badge: 'PRO',
      price_label: 'R$ 497/mês',
      description: 'Para equipes em crescimento com Campanhas, Agendamentos e Relatórios Avançados.',
      max_agents: 10,
      max_inboxes: 5,
      max_accounts: 3,
      whitelabel_enabled: false,
      captain_ai_enabled: false,
      custom_branding_enabled: false,
      features: PRO_FEATURES,
      sidebar_items: %w[
        scheduled_messages
        calendar_appointments
        conversation_actions
        macros
        conversation_info
        contact_attributes
        contact_notes
        shared_files
        previous_conversation
      ]
    },
    'business' => {
      key: 'business',
      name: 'Business AI & Omnichannel',
      badge: 'BUSINESS',
      price_label: 'R$ 997/mês',
      description: 'Operação completa com Captain IA V2, SLA, Auditoria, Shopify, Workflows e CRM.',
      max_agents: 30,
      max_inboxes: 15,
      max_accounts: 10,
      whitelabel_enabled: false,
      captain_ai_enabled: true,
      custom_branding_enabled: false,
      features: BUSINESS_FEATURES,
      sidebar_items: %w[
        scheduled_messages
        calendar_appointments
        conversation_actions
        shopify_orders
        macros
        conversation_info
        contact_attributes
        contact_notes
        shared_files
        previous_conversation
        conversation_participants
      ]
    },
    'elite_whitelabel' => {
      key: 'elite_whitelabel',
      name: 'Elite White-Label Unlimited',
      badge: 'ELITE WHITE-LABEL',
      price_label: 'Enterprise / White-Label',
      description: 'Licença Master SaaS + White-Label ilimitada com marca própria, domínios, SAML e remoção total de marca.',
      max_agents: 10_000,
      max_inboxes: 10_000,
      max_accounts: 10_000,
      whitelabel_enabled: true,
      captain_ai_enabled: true,
      custom_branding_enabled: true,
      features: ELITE_WHITELABEL_FEATURES,
      sidebar_items: ALL_SIDEBAR_ITEMS
    }
  }.freeze

  def self.tiers
    TIERS
  end

  def self.active?
    true
  end

  def self.platform_header
    PLATFORM_HEADER
  end

  def self.current_tier_key
    raw = get_config('MSC_ELITE_LICENSE_TIER').presence || ENV.fetch('MSC_ELITE_LICENSE_TIER', 'elite_whitelabel')
    TIERS.key?(raw.to_s) ? raw.to_s : 'elite_whitelabel'
  end

  def self.current_tier
    TIERS[current_tier_key]
  end

  def self.current_limits
    tier = current_tier
    custom_seats = get_config('INSTALLATION_PRICING_PLAN_QUANTITY').to_i
    {
      max_agents: custom_seats.positive? ? custom_seats : tier[:max_agents],
      max_inboxes: tier[:max_inboxes],
      max_accounts: tier[:max_accounts]
    }
  end

  def self.license_holder
    get_config('MSC_ELITE_LICENSE_HOLDER').presence ||
      get_config('BRAND_NAME').presence ||
      get_config('INSTALLATION_NAME').presence ||
      'Meu Super Chat Elite'
  end

  def self.license_key
    existing = get_config('MSC_ELITE_LICENSE_KEY').presence
    return existing if existing.present?

    generated = generate_license_key(tier: current_tier_key, holder: license_holder)
    set_config('MSC_ELITE_LICENSE_KEY', generated, locked: false)
    generated
  end

  def self.generate_license_key(tier: 'elite_whitelabel', holder: 'MeuSuperChat', seats: nil)
    tier_code = tier.to_s.upcase.split('_').first[0..4]
    seat_count = seats || TIERS.dig(tier.to_s, :max_agents) || 10_000
    secret = Rails.application.secret_key_base.to_s.presence || 'msc-elite-secret'
    digest = OpenSSL::HMAC.hexdigest('SHA256', secret, "#{tier}:#{holder}:#{seat_count}")[0..11].upcase
    "MSC-#{tier_code}-#{seat_count}-#{digest[0..3]}-#{digest[4..7]}-#{digest[8..11]}"
  end

  def self.update_instance_license!(tier:, holder: nil, seats: nil, sync_all_accounts: false)
    tier_key = TIERS.key?(tier.to_s) ? tier.to_s : 'elite_whitelabel'
    tier_cfg = TIERS[tier_key]
    holder_name = holder.presence || license_holder
    seat_limit = (seats.presence || tier_cfg[:max_agents]).to_i
    seat_limit = tier_cfg[:max_agents] if seat_limit <= 0

    new_key = generate_license_key(tier: tier_key, holder: holder_name, seats: seat_limit)

    set_config('MSC_ELITE_LICENSE_TIER', tier_key, locked: false)
    set_config('MSC_ELITE_LICENSE_HOLDER', holder_name, locked: false)
    set_config('MSC_ELITE_LICENSE_KEY', new_key, locked: false)
    set_config('INSTALLATION_PRICING_PLAN', 'enterprise', locked: true)
    set_config('INSTALLATION_PRICING_PLAN_QUANTITY', seat_limit, locked: true)

    if ActiveModel::Type::Boolean.new.cast(sync_all_accounts)
      Account.find_each do |account|
        apply_tier_to_account!(account, tier_key)
      end
    end

    GlobalConfig.clear_cache if defined?(GlobalConfig)
    status_summary
  end

  def self.account_tier_key(account)
    return current_tier_key unless account

    acct_tier = account.settings&.dig('elite_plan_tier') || account.custom_attributes&.dig('elite_plan_tier')
    TIERS.key?(acct_tier.to_s) ? acct_tier.to_s : current_tier_key
  end

  def self.account_tier(account)
    TIERS[account_tier_key(account)]
  end

  def self.apply_tier_to_account!(account, tier_key)
    tier_key = TIERS.key?(tier_key.to_s) ? tier_key.to_s : 'elite_whitelabel'
    tier = TIERS[tier_key]

    settings = (account.settings || {}).dup
    settings['elite_plan_tier'] = tier_key
    settings['conversation_sidebar_visible_items'] = tier[:sidebar_items]
    account.settings = settings

    limits = (account.limits || {}).dup
    limits['agents'] = tier[:max_agents]
    limits['inboxes'] = tier[:max_inboxes]
    account.limits = limits

    all_managed_features = ELITE_WHITELABEL_FEATURES
    features_to_disable = all_managed_features - tier[:features]
    account.disable_features(*features_to_disable) if features_to_disable.any?
    account.enable_features(*tier[:features]) if tier[:features].any?

    account.save!

    if defined?(::Internal::Accounts::InternalAttributesService)
      begin
        svc = ::Internal::Accounts::InternalAttributesService.new(account)
        svc.manually_managed_features = tier[:features] & svc.valid_feature_names
      rescue StandardError => e
        Rails.logger.warn "[EliteLicenseEngine] Could not sync internal attributes for account #{account.id}: #{e.message}"
      end
    end

    tier
  end

  def self.status_summary
    tier = current_tier
    limits = current_limits
    {
      platform: PLATFORM_NAME,
      tier_key: tier[:key],
      tier_name: tier[:name],
      badge: tier[:badge],
      price_label: tier[:price_label],
      description: tier[:description],
      license_key: license_key,
      license_holder: license_holder,
      whitelabel_enabled: tier[:whitelabel_enabled],
      captain_ai_enabled: tier[:captain_ai_enabled],
      custom_branding_enabled: tier[:custom_branding_enabled],
      max_agents: limits[:max_agents],
      max_inboxes: limits[:max_inboxes],
      max_accounts: limits[:max_accounts],
      active_accounts: (Account.count rescue 0),
      active_users: (User.count rescue 0),
      active_inboxes: (Inbox.count rescue 0),
      verified_locally: true
    }
  end

  def self.get_config(name)
    InstallationConfig.find_by(name: name)&.value
  rescue StandardError
    nil
  end

  def self.set_config(name, value, locked: false)
    cfg = InstallationConfig.find_or_initialize_by(name: name)
    cfg.value = value
    cfg.locked = locked
    cfg.save!
  rescue StandardError => e
    Rails.logger.error "[EliteLicenseEngine] Failed to set config #{name}: #{e.message}"
  end
end

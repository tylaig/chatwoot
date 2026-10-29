# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'date'

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
    channel_facebook
    channel_instagram
    help_center
    team_management
    channel_voice
    captain_integration
    captain_integration_v2
  ].freeze

  PRO_FEATURES = (STARTER_FEATURES + %w[
    campaigns
    linear_integration
    data_import
  ]).uniq.freeze

  BUSINESS_FEATURES = (PRO_FEATURES + %w[
    sla
    custom_roles
    csat_review_notes
    conversation_required_attributes
    advanced_assignment
    custom_tools
    companies
  ]).uniq.freeze

  ELITE_WHITELABEL_FEATURES = (BUSINESS_FEATURES + %w[
    audit_logs
    disable_branding
    saml
  ]).uniq.freeze

  TIER_CODES = {
    'starter' => 'STARTER',
    'pro' => 'PRO',
    'business' => 'BUSINESS',
    'elite_whitelabel' => 'ELITE'
  }.freeze

  CODE_TO_TIER = {
    'STARTER' => 'starter',
    'START' => 'starter',
    'HACKER' => 'starter',
    'PRO' => 'pro',
    'STARTUPS' => 'pro',
    'SCALE' => 'business',
    'BUSINESS' => 'business',
    'BUSIN' => 'business',
    'ELITE' => 'elite_whitelabel',
    'ELITE_WHITELABEL' => 'elite_whitelabel',
    'ENTERPRISE' => 'elite_whitelabel',
    'WHITE_LABEL' => 'elite_whitelabel'
  }.freeze

  SELF_SERVICE_TIERS = %w[starter pro business].freeze

  TIERS = {
    'starter' => {
      key: 'starter',
      name: 'Starter SaaS',
      badge: 'STARTER',
      price_label: 'R$ 197/mês',
      description: 'Ideal para pequenas operações iniciando atendimento centralizado com IA.',
      max_agents: 3,
      max_inboxes: 2,
      max_accounts: 1,
      captain_responses: 500,
      captain_documents: 25,
      whitelabel_enabled: false,
      captain_ai_enabled: true,
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
      description: 'Para equipes em crescimento com Campanhas, Agendamentos, IA e Relatórios Avançados.',
      max_agents: 10,
      max_inboxes: 5,
      max_accounts: 3,
      captain_responses: 2_500,
      captain_documents: 100,
      whitelabel_enabled: false,
      captain_ai_enabled: true,
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
      description: 'Operação completa com Captain IA V2 em alta escala, SLA, Auditoria, Shopify, Workflows e CRM.',
      max_agents: 30,
      max_inboxes: 15,
      max_accounts: 10,
      captain_responses: 10_000,
      captain_documents: 500,
      whitelabel_enabled: false,
      captain_ai_enabled: true,
      custom_branding_enabled: true,
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
      captain_responses: 1_000_000,
      captain_documents: 10_000,
      whitelabel_enabled: true,
      captain_ai_enabled: true,
      custom_branding_enabled: true,
      features: ELITE_WHITELABEL_FEATURES,
      sidebar_items: ALL_SIDEBAR_ITEMS
    }
  }.freeze

  BRANDING_KEYS = %w[
    INSTALLATION_NAME
    BRAND_NAME
    BRAND_COLOR
    BRAND_URL
    WIDGET_BRAND_URL
    LOGO
    LOGO_DARK
    LOGO_THUMBNAIL
    LOGO_EMAIL
    TERMS_URL
    PRIVACY_URL
    DISPLAY_MANIFEST
  ].freeze

  WHITELABEL_PRESETS = {
    'meusuperchat' => {
      key: 'meusuperchat',
      label: 'Meu Super Chat (SaaS)',
      'INSTALLATION_NAME' => 'Meu Super Chat',
      'BRAND_NAME' => 'Meu Super Chat',
      'BRAND_COLOR' => '#10B981',
      'BRAND_URL' => 'https://meusuper.app',
      'WIDGET_BRAND_URL' => 'https://chat.meusuper.app',
      'TERMS_URL' => 'https://chat.meusuper.app/lp#termos',
      'PRIVACY_URL' => 'https://chat.meusuper.app/lp#privacidade',
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
      'LOGO' => '/brand-assets/logo.svg',
      'LOGO_DARK' => '/brand-assets/logo_dark.svg',
      'LOGO_EMAIL' => '/brand-assets/logo_email.png',
      'DISPLAY_MANIFEST' => false,
      default_sidebar_items: ALL_SIDEBAR_ITEMS
    },
    'gamessafari' => {
      key: 'gamessafari',
      label: 'Games Safari (White-Label)',
      'INSTALLATION_NAME' => 'Games Safari',
      'BRAND_NAME' => 'Games Safari',
      'BRAND_COLOR' => '#10B981',
      'BRAND_URL' => 'https://gamessafari.com',
      'WIDGET_BRAND_URL' => 'https://inbox.gamessafari.com',
      'TERMS_URL' => 'https://gamessafari.com/policies/terms-of-service',
      'PRIVACY_URL' => 'https://gamessafari.com/policies/privacy-policy',
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
      'LOGO' => '/brand-assets/logo.svg',
      'LOGO_DARK' => '/brand-assets/logo_dark.svg',
      'LOGO_EMAIL' => '/brand-assets/logo_email.png',
      'DISPLAY_MANIFEST' => false,
      default_sidebar_items: %w[conversation_info shopify_orders]
    }
  }.freeze

  def self.tiers
    TIERS
  end

  def self.whitelabel_presets
    WHITELABEL_PRESETS
  end

  def self.active?
    !expired?
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
      max_accounts: tier[:max_accounts],
      captain_responses: tier[:captain_responses],
      captain_documents: tier[:captain_documents]
    }
  end

  def self.license_holder
    get_config('MSC_ELITE_LICENSE_HOLDER').presence ||
      get_config('BRAND_NAME').presence ||
      get_config('INSTALLATION_NAME').presence ||
      'Meu Super Chat'
  end

  def self.expires_at
    raw = get_config('MSC_ELITE_LICENSE_EXPIRES_AT').to_s.strip
    return nil if raw.blank? || raw.casecmp('PERP').zero?

    Date.parse(raw).iso8601
  rescue StandardError
    nil
  end

  def self.expired?
    exp = expires_at
    return false if exp.blank?

    Date.parse(exp) < Date.current
  rescue StandardError
    false
  end

  def self.license_key
    existing = get_config('MSC_ELITE_LICENSE_KEY').presence
    return existing if existing.present?

    generated = generate_license_key(
      tier: current_tier_key,
      holder: license_holder,
      seats: current_limits[:max_agents],
      expires_at: expires_at
    )
    set_config('MSC_ELITE_LICENSE_KEY', generated, locked: false)
    generated
  end

  def self.secret_key
    Rails.application.secret_key_base.to_s.presence || 'msc-elite-secret'
  end

  def self.normalize_exp_token(expires_at)
    return 'PERP' if expires_at.blank? || expires_at.to_s.strip.casecmp('PERP').zero?

    raw = expires_at.to_s.strip
    if raw.match?(/\A\d{8}\z/)
      Date.strptime(raw, '%Y%m%d').strftime('%Y%m%d')
    else
      Date.parse(raw).strftime('%Y%m%d')
    end
  rescue StandardError
    'PERP'
  end

  # Canonical format: MSC-<TIER>-<SEATS>-<EXP_YYYYMMDD_OR_PERP>-<HMAC12>
  def self.generate_license_key(tier: 'elite_whitelabel', holder: 'Meu Super Chat', seats: nil, expires_at: nil)
    tier_key = resolve_tier_key(tier)
    tier_code = TIER_CODES[tier_key] || 'ELITE'
    seat_count = (seats.presence || TIERS.dig(tier_key, :max_agents) || 10_000).to_i
    seat_count = TIERS.dig(tier_key, :max_agents) || 10_000 if seat_count <= 0
    exp_token = normalize_exp_token(expires_at)
    clean_holder = holder.to_s.strip.presence || 'Meu Super Chat'

    hmac12 = compute_hmac12(tier_key: tier_key, holder: clean_holder, seats: seat_count, exp_token: exp_token)
    "MSC-#{tier_code}-#{seat_count}-#{exp_token}-#{hmac12}"
  end

  def self.compute_hmac12(tier_key:, holder:, seats:, exp_token: 'PERP')
    OpenSSL::HMAC.hexdigest('SHA256', secret_key, "#{tier_key}:#{holder.to_s.strip}:#{seats.to_i}:#{exp_token}")[0..11].upcase
  end

  def self.compute_legacy_hmac12(tier_key:, holder:, seats:)
    OpenSSL::HMAC.hexdigest('SHA256', secret_key, "#{tier_key}:#{holder.to_s.strip}:#{seats.to_i}")[0..11].upcase
  end

  def self.resolve_tier_key(tier_or_code)
    return current_tier_key if tier_or_code.blank?

    str = tier_or_code.to_s.strip
    return str.downcase if TIERS.key?(str.downcase)

    CODE_TO_TIER[str.upcase] || 'elite_whitelabel'
  end

  def self.resolve_self_service_tier(tier_or_code)
    return 'starter' if tier_or_code.blank?

    str = tier_or_code.to_s.strip
    candidate = TIERS.key?(str.downcase) ? str.downcase : CODE_TO_TIER[str.upcase]
    SELF_SERVICE_TIERS.include?(candidate) ? candidate : 'starter'
  end

  def self.resolve_billing_tier_key(plan_or_tier)
    return nil if plan_or_tier.blank?

    str = plan_or_tier.to_s.strip
    return str.downcase if TIERS.key?(str.downcase)
    return CODE_TO_TIER[str.upcase] if CODE_TO_TIER.key?(str.upcase)

    down = str.downcase
    if down.include?('elite') || down.include?('white') || down.include?('enterprise')
      'elite_whitelabel'
    elsif down.include?('business') || down.include?('scale')
      'business'
    elsif down.include?('pro') || down.include?('growth') || down.include?('startup')
      'pro'
    elsif down.include?('starter') || down.include?('start') || down.include?('hacker')
      'starter'
    end
  end

  def self.inspect_license_key(key, tier: nil, holder: nil, seats: nil, expires_at: nil)
    raw_key = key.to_s.strip.upcase
    return { valid: false, hmac_valid: false, expired: false, reason: 'Chave de licença em branco' } if raw_key.blank?

    clean_holder = (holder.presence || license_holder).to_s.strip

    # 1) New canonical format: MSC-<TIER>-<SEATS>-<EXP_YYYYMMDD_OR_PERP>-<HMAC12>
    # Also tolerates hyphenated HMAC12 (e.g. XXXX-XXXX-XXXX) after EXP token
    if (m = raw_key.match(/\AMSC-([A-Z_]+)-(\d+)-(PERP|\d{8})-([A-F0-9]{4}-?[A-F0-9]{4}-?[A-F0-9]{4})\z/))
      code_part = m[1]
      key_seats = m[2].to_i
      exp_token = m[3]
      sig_part = m[4].delete('-')
      key_tier = CODE_TO_TIER[code_part]

      return { valid: false, hmac_valid: false, expired: false, reason: "Tier desconhecido na chave: #{code_part}" } unless key_tier

      if tier.present? && resolve_tier_key(tier) != key_tier
        return { valid: false, hmac_valid: false, expired: false, tier_key: key_tier, reason: 'O tier informado não corresponde ao tier codificado na chave' }
      end

      if seats.present? && seats.to_i.positive? && seats.to_i != key_seats
        return { valid: false, hmac_valid: false, expired: false, tier_key: key_tier, seats: key_seats, reason: 'A quantidade de assentos não corresponde à chave' }
      end

      if expires_at.present? && normalize_exp_token(expires_at) != exp_token
        return { valid: false, hmac_valid: false, expired: false, tier_key: key_tier, seats: key_seats, reason: 'A data de expiração não corresponde à chave' }
      end

      expected_exact = compute_hmac12(tier_key: key_tier, holder: clean_holder, seats: key_seats, exp_token: exp_token)
      expected_down = compute_hmac12(tier_key: key_tier, holder: clean_holder.downcase, seats: key_seats, exp_token: exp_token)
      hmac_ok = ActiveSupport::SecurityUtils.secure_compare(sig_part, expected_exact) ||
                ActiveSupport::SecurityUtils.secure_compare(sig_part, expected_down)

      parsed_exp = nil
      is_expired = false
      if exp_token != 'PERP'
        begin
          exp_date = Date.strptime(exp_token, '%Y%m%d')
          parsed_exp = exp_date.iso8601
          is_expired = exp_date < Date.current
        rescue StandardError
          return { valid: false, hmac_valid: false, expired: false, reason: 'Data de expiração inválida na chave' }
        end
      end

      reason = if !hmac_ok
                 'Assinatura criptográfica HMAC inválida para este titular/instância'
               elsif is_expired
                 "Chave de licença expirada em #{parsed_exp}"
               else
                 'Chave verificada com sucesso via HMAC-SHA256'
               end

      return {
        valid: hmac_ok && !is_expired,
        hmac_valid: hmac_ok,
        expired: is_expired,
        tier_key: key_tier,
        seats: key_seats,
        exp_token: exp_token,
        expires_at: parsed_exp,
        holder: clean_holder,
        reason: reason
      }
    end

    # 2) Legacy format: MSC-<TIER_CODE>-<SEATS>-<XXXX>-<XXXX>-<XXXX>
    if (m = raw_key.match(/\AMSC-([A-Z_]+)-(\d+)-([A-F0-9]{4})-([A-F0-9]{4})-([A-F0-9]{4})\z/))
      code_part = m[1]
      key_seats = m[2].to_i
      sig_part = "#{m[3]}#{m[4]}#{m[5]}"
      key_tier = CODE_TO_TIER[code_part]

      return { valid: false, hmac_valid: false, expired: false, reason: "Tier desconhecido na chave: #{code_part}" } unless key_tier

      if tier.present? && resolve_tier_key(tier) != key_tier
        return { valid: false, hmac_valid: false, expired: false, tier_key: key_tier, reason: 'O tier informado não corresponde ao tier da chave' }
      end

      if seats.present? && seats.to_i.positive? && seats.to_i != key_seats
        return { valid: false, hmac_valid: false, expired: false, tier_key: key_tier, seats: key_seats, reason: 'A quantidade de assentos não corresponde à chave' }
      end

      expected_legacy = compute_legacy_hmac12(tier_key: key_tier, holder: clean_holder, seats: key_seats)
      hmac_ok = ActiveSupport::SecurityUtils.secure_compare(sig_part, expected_legacy)

      return {
        valid: hmac_ok,
        hmac_valid: hmac_ok,
        expired: false,
        tier_key: key_tier,
        seats: key_seats,
        exp_token: 'PERP',
        expires_at: nil,
        holder: clean_holder,
        reason: hmac_ok ? 'Chave legada verificada com sucesso via HMAC-SHA256' : 'Assinatura HMAC inválida'
      }
    end

    { valid: false, hmac_valid: false, expired: false, reason: 'Formato de chave inválido. Esperado: MSC-<TIER>-<SEATS>-<EXP>-<HMAC12>' }
  end

  def self.verify_license_key(key, tier: nil, holder: nil, seats: nil, expires_at: nil)
    inspect_license_key(key, tier: tier, holder: holder, seats: seats, expires_at: expires_at)[:valid] == true
  end

  def self.activate_with_key!(license_key:, holder:, tier: nil, seats: nil, expires_at: nil, sync_all_accounts: false)
    clean_holder = holder.to_s.strip.presence || license_holder
    inspection = inspect_license_key(license_key, tier: tier, holder: clean_holder, seats: seats, expires_at: expires_at)

    raise ArgumentError, inspection[:reason] unless inspection[:valid]

    resolved_tier = inspection[:tier_key]
    resolved_seats = inspection[:seats]
    resolved_exp = inspection[:expires_at]

    set_config('MSC_ELITE_LICENSE_TIER', resolved_tier, locked: false)
    set_config('MSC_ELITE_LICENSE_HOLDER', clean_holder, locked: false)
    set_config('MSC_ELITE_LICENSE_KEY', license_key.to_s.strip.upcase, locked: false)
    set_config('MSC_ELITE_LICENSE_EXPIRES_AT', resolved_exp.presence || '', locked: false)
    set_config('INSTALLATION_PRICING_PLAN', resolved_tier, locked: false)
    set_config('INSTALLATION_PRICING_PLAN_QUANTITY', resolved_seats, locked: false)

    if ActiveModel::Type::Boolean.new.cast(sync_all_accounts)
      Account.find_each do |account|
        apply_tier_to_account!(account, resolved_tier, custom_limits: { agents: resolved_seats })
      end
    end

    GlobalConfig.clear_cache if defined?(GlobalConfig)
    status_summary
  end

  def self.update_instance_license!(tier:, holder: nil, seats: nil, expires_at: nil, sync_all_accounts: false)
    tier_key = resolve_tier_key(tier)
    tier_cfg = TIERS[tier_key]
    holder_name = holder.to_s.strip.presence || license_holder
    seat_limit = (seats.presence || tier_cfg[:max_agents]).to_i
    seat_limit = tier_cfg[:max_agents] if seat_limit <= 0

    new_key = generate_license_key(tier: tier_key, holder: holder_name, seats: seat_limit, expires_at: expires_at)
    activate_with_key!(
      license_key: new_key,
      holder: holder_name,
      tier: tier_key,
      seats: seat_limit,
      expires_at: expires_at,
      sync_all_accounts: sync_all_accounts
    )
  end

  def self.whitelabel_config
    cfg = {}
    BRANDING_KEYS.each do |k|
      val = get_config(k)
      cfg[k] = val
    end
    cfg['INSTALLATION_NAME'] = cfg['INSTALLATION_NAME'].presence || 'Meu Super Chat'
    cfg['BRAND_NAME'] = cfg['BRAND_NAME'].presence || cfg['INSTALLATION_NAME']
    cfg['BRAND_COLOR'] = cfg['BRAND_COLOR'].presence || '#10B981'
    cfg['BRAND_URL'] = cfg['BRAND_URL'].presence || 'https://meusuper.app'
    cfg['WIDGET_BRAND_URL'] = cfg['WIDGET_BRAND_URL'].presence || 'https://chat.meusuper.app'
    cfg['LOGO'] = cfg['LOGO'].presence || '/brand-assets/logo.svg'
    cfg['LOGO_DARK'] = cfg['LOGO_DARK'].presence || '/brand-assets/logo_dark.svg'
    cfg['LOGO_THUMBNAIL'] = cfg['LOGO_THUMBNAIL'].presence || '/brand-assets/logo_thumbnail.svg'
    cfg['LOGO_EMAIL'] = cfg['LOGO_EMAIL'].presence || '/brand-assets/logo_email.png'
    cfg['TERMS_URL'] = cfg['TERMS_URL'].presence || 'https://chat.meusuper.app/lp#termos'
    cfg['PRIVACY_URL'] = cfg['PRIVACY_URL'].presence || 'https://chat.meusuper.app/lp#privacidade'
    cfg['DISPLAY_MANIFEST'] = ActiveModel::Type::Boolean.new.cast(cfg['DISPLAY_MANIFEST'])

    preset_key = get_config('MSC_WHITELABEL_PRESET').to_s.presence
    unless preset_key
      preset_key = if cfg['INSTALLATION_NAME'].to_s.casecmp('Games Safari').zero?
                     'gamessafari'
                   elsif cfg['INSTALLATION_NAME'].to_s.casecmp('Meu Super Chat').zero?
                     'meusuperchat'
                   else
                     'custom'
                   end
    end
    cfg['active_preset'] = preset_key
    cfg
  end

  def self.apply_whitelabel_branding!(params_or_preset, apply_sidebar: nil, account_id: nil)
    raw_input = if params_or_preset.respond_to?(:to_unsafe_h)
                  params_or_preset.to_unsafe_h
                elsif params_or_preset.is_a?(Hash)
                  params_or_preset
                else
                  { 'preset' => params_or_preset.to_s }
                end.with_indifferent_access

    preset_name = raw_input[:preset].to_s.strip.downcase
    preset = WHITELABEL_PRESETS[preset_name]

    merged = whitelabel_config.dup
    if preset
      BRANDING_KEYS.each do |k|
        merged[k] = preset[k] if preset.key?(k)
      end
    end

    BRANDING_KEYS.each do |k|
      next unless raw_input.key?(k) && !raw_input[k].nil?

      val = raw_input[k]
      next if preset && val.is_a?(String) && val.strip.empty? && !raw_input[:explicit_override]

      merged[k] = k == 'DISPLAY_MANIFEST' ? ActiveModel::Type::Boolean.new.cast(val) : val.to_s.strip
    end

    BRANDING_KEYS.each do |k|
      set_config(k, merged[k], locked: false)
    end

    detected_preset = if preset && merged['INSTALLATION_NAME'] == preset['INSTALLATION_NAME']
                        preset_name
                      elsif merged['INSTALLATION_NAME'].to_s.casecmp('Games Safari').zero?
                        'gamessafari'
                      elsif merged['INSTALLATION_NAME'].to_s.casecmp('Meu Super Chat').zero?
                        'meusuperchat'
                      else
                        'custom'
                      end

    set_config('MSC_WHITELABEL_PRESET', detected_preset, locked: false)
    set_config('MSC_WHITELABEL_CUSTOMIZED', 'true', locked: false)

    should_apply_sidebar = if !apply_sidebar.nil?
                             ActiveModel::Type::Boolean.new.cast(apply_sidebar)
                           elsif raw_input.key?(:apply_sidebar)
                             ActiveModel::Type::Boolean.new.cast(raw_input[:apply_sidebar])
                           else
                             params_or_preset.is_a?(String) || params_or_preset.is_a?(Symbol) || preset.present?
                           end

    sidebar_list = raw_input[:sidebar_items].presence || (preset && preset[:default_sidebar_items])
    if should_apply_sidebar && sidebar_list.present?
      target_account = account_id.present? ? Account.find_by(id: account_id) : Account.order(:id).first
      if target_account
        settings = (target_account.settings || {}).dup
        settings['conversation_sidebar_visible_items'] = Array(sidebar_list).map(&:to_s) & ALL_SIDEBAR_ITEMS
        target_account.settings = settings
        target_account.save!
      end
    end

    GlobalConfig.clear_cache if defined?(GlobalConfig)
    whitelabel_config
  end

  def self.account_tier_key(account)
    return current_tier_key unless account

    acct_tier = account.settings&.dig('elite_plan_tier') ||
                account.custom_attributes&.dig('plan_name') ||
                account.custom_attributes&.dig('elite_plan_tier')
    TIERS.key?(acct_tier.to_s) ? acct_tier.to_s : current_tier_key
  end

  def self.account_tier(account)
    TIERS[account_tier_key(account)]
  end

  def self.apply_tier_to_account!(account, tier_key, custom_limits: {}, sync_sidebar: true)
    resolved_key = TIERS.key?(tier_key.to_s) ? tier_key.to_s : account_tier_key(account)
    tier = TIERS[resolved_key]
    custom = (custom_limits || {}).with_indifferent_access

    max_agents = (custom[:agents].presence || tier[:max_agents]).to_i
    max_agents = tier[:max_agents] if max_agents <= 0

    max_inboxes = (custom[:inboxes].presence || tier[:max_inboxes]).to_i
    max_inboxes = tier[:max_inboxes] if max_inboxes <= 0

    captain_responses = (custom[:captain_responses].presence || tier[:captain_responses]).to_i
    captain_responses = tier[:captain_responses] if captain_responses.negative?

    captain_documents = (custom[:captain_documents].presence || tier[:captain_documents]).to_i
    captain_documents = tier[:captain_documents] if captain_documents.negative?

    settings = (account.settings || {}).dup
    settings['elite_plan_tier'] = resolved_key
    if ActiveModel::Type::Boolean.new.cast(sync_sidebar) || settings['conversation_sidebar_visible_items'].blank?
      settings['conversation_sidebar_visible_items'] = tier[:sidebar_items]
    end
    account.settings = settings

    custom_attrs = (account.custom_attributes || {}).dup
    custom_attrs['plan_name'] = resolved_key
    custom_attrs['subscribed_quantity'] = max_agents
    account.custom_attributes = custom_attrs

    existing_limits = (account.limits || {}).dup
    new_limits = {}
    new_limits['emails'] = existing_limits['emails'].to_i if existing_limits['emails'].present?
    new_limits['agents'] = max_agents
    new_limits['inboxes'] = max_inboxes
    new_limits['captain_responses'] = captain_responses
    new_limits['captain_documents'] = captain_documents
    account.limits = new_limits

    all_managed_features = ELITE_WHITELABEL_FEATURES
    features_to_disable = (all_managed_features - tier[:features])
    features_to_enable = tier[:features]

    features_to_disable.each do |f|
      setter = "feature_#{f}="
      account.public_send(setter, false) if account.respond_to?(setter)
    end
    features_to_enable.each do |f|
      setter = "feature_#{f}="
      account.public_send(setter, true) if account.respond_to?(setter)
    end

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
    key = license_key
    holder = license_holder
    exp = expires_at
    inspection = inspect_license_key(key, holder: holder)
    total_ai_used = begin
      Account.sum("COALESCE((custom_attributes ->> 'captain_responses_usage')::int, 0)")
    rescue StandardError
      0
    end

    {
      platform: PLATFORM_NAME,
      tier_key: tier[:key],
      tier_name: tier[:name],
      badge: tier[:badge],
      price_label: tier[:price_label],
      description: tier[:description],
      license_key: key,
      license_holder: holder,
      expires_at: exp,
      expired: expired?,
      hmac_valid: inspection[:hmac_valid],
      whitelabel_enabled: tier[:whitelabel_enabled],
      captain_ai_enabled: tier[:captain_ai_enabled],
      custom_branding_enabled: tier[:custom_branding_enabled],
      max_agents: limits[:max_agents],
      max_inboxes: limits[:max_inboxes],
      max_accounts: limits[:max_accounts],
      captain_responses: limits[:captain_responses],
      captain_documents: limits[:captain_documents],
      total_captain_consumed: total_ai_used,
      active_accounts: (Account.count rescue 0),
      active_users: (User.count rescue 0),
      active_inboxes: (Inbox.count rescue 0),
      verified_locally: inspection[:hmac_valid] && !expired?,
      whitelabel: whitelabel_config
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

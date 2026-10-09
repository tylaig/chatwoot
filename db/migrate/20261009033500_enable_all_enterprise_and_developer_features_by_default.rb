class EnableAllEnterpriseAndDeveloperFeaturesByDefault < ActiveRecord::Migration[7.1]
  def up
    # 1. Ensure pricing plan is enterprise
    plan_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    plan_config.value = 'enterprise'
    plan_config.locked = true
    plan_config.save!

    qty_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    qty_config.value = 10_000
    qty_config.locked = true
    qty_config.save!

    # 2. Update ACCOUNT_LEVEL_FEATURE_DEFAULTS
    feature_list = YAML.safe_load(Rails.root.join('config/features.yml').read)
    deprecated = %w[message_reply_to whatsapp_embedded_signup whatsapp_reconfigure reply_mailer_migration]

    features_to_enable = feature_list.reject { |f| deprecated.include?(f['name']) }

    account_defaults = InstallationConfig.find_or_initialize_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    account_defaults.value = features_to_enable.map do |f|
      { 'name' => f['name'], 'display_name' => f['display_name'], 'enabled' => true }
    end
    account_defaults.locked = true
    account_defaults.save!

    # 3. Enable all features for existing accounts
    flag_symbols = features_to_enable.map { |f| "feature_#{f['name']}".to_sym }

    Account.find_each do |account|
      flag_symbols.each do |flag|
        account.enable_flag(flag) if account.all_feature_flags.include?(flag)
      end
      account.save!
    end

    # 4. Promote account administrators to SuperAdmin
    admin_user_ids = AccountUser.where(role: :administrator).pluck(:user_id)
    User.where(id: admin_user_ids, type: [nil, '', 'user']).update_all(type: 'SuperAdmin') if admin_user_ids.present?

    # 5. Clear caches
    GlobalConfig.clear_cache
    Rails.cache.clear
  rescue StandardError => e
    Rails.logger.error "Migration error: #{e.message}"
  end

  def down
    # No-op
  end
end

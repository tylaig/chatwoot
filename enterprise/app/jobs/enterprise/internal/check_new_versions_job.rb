module Enterprise::Internal::CheckNewVersionsJob
  def perform
    super
    sync_elite_license_plan
    reconcile_premium_config_and_features
  end

  private

  def sync_elite_license_plan
    return unless defined?(EliteLicenseEngine)

    seats = EliteLicenseEngine.current_limits[:max_agents]
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN', value: 'enterprise')
    update_installation_config(key: 'INSTALLATION_PRICING_PLAN_QUANTITY', value: seats)
  end

  def update_installation_config(key:, value:)
    config = InstallationConfig.find_or_initialize_by(name: key)
    config.value = value
    config.locked = true
    config.save!
  end

  def reconcile_premium_config_and_features
    Internal::ReconcilePlanConfigService.new.perform
  end
end

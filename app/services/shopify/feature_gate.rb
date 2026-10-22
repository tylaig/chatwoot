class Shopify::FeatureGate
  ACCOUNT_FEATURE = 'shopify_integration'.freeze
  GLOBAL_CONFIG = 'ENABLE_SHOPIFY_INTEGRATION'.freeze

  def self.enabled?(account: nil)
    return true if account&.feature_enabled?(ACCOUNT_FEATURE)
    return false unless globally_enabled?

    account.nil? || account.feature_enabled?(ACCOUNT_FEATURE)
  end

  def self.globally_enabled?
    configured_value = GlobalConfigService.load(GLOBAL_CONFIG, 'true')
    ActiveModel::Type::Boolean.new.cast(configured_value)
  end
end

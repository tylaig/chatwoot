# frozen_string_literal: true
require 'ruby_llm'
require_relative 'zz_gs_kie_compat'
module GsKieModelRoute
  def resolve(model_id, provider: nil, assume_exists: false, config: nil)
    return super unless model_id.to_s == 'gemini-4-argon'
    scoped = (config || RubyLLM.config).dup
    scoped.openai_api_base = 'https://api.kie.ai/gemini-4-argon-openai/v1'
    scoped.openai_api_key = InstallationConfig.find_by(name: 'GAMES_SAFARI_KIE_API_KEY')&.value
    raise 'Missing Games Safari Kie key' if scoped.openai_api_key.blank?
    super(model_id, provider: :openai, assume_exists: true, config: scoped)
  end
end
RubyLLM::Models.singleton_class.prepend(GsKieModelRoute)
module GsKieAllStoreRoute
  KIE_ASSISTANT_IDS = [1, 2, 3, 4].freeze
  private
  def all_store_kie_enabled?
    InstallationConfig.find_by(name: 'GAMES_ALL_STORES_KIE_ENABLED')&.value == true
  end
end
module GsKieAssistantRoute
  include GsKieAllStoreRoute
  def agent_model
    return 'gemini-4-argon' if KIE_ASSISTANT_IDS.include?(id) && all_store_kie_enabled? && config['model'].to_s == 'gemini-4-argon'
    # Captain V2 must honor the assistant's explicit gateway model. The account
    # level captain_models setting is an old UI override and otherwise silently
    # changes gemini-3.8-flash-high back to gemini-3-flash.
    return config['model'].to_s if KIE_ASSISTANT_IDS.include?(id) && account&.feature_enabled?('captain_integration_v2') && config['model'].present?
    super
  end
end
module GsKieScenarioRoute
  include GsKieAllStoreRoute
  def agent_model
    return 'gemini-4-argon' if KIE_ASSISTANT_IDS.include?(assistant_id) && all_store_kie_enabled? && assistant.config['model'].to_s == 'gemini-4-argon'
    super
  end
end
Rails.application.config.to_prepare do
  Captain::Assistant.prepend(GsKieAssistantRoute) unless Captain::Assistant.ancestors.include?(GsKieAssistantRoute)
  Captain::Scenario.prepend(GsKieScenarioRoute) unless Captain::Scenario.ancestors.include?(GsKieScenarioRoute)
end

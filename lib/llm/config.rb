require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-5.6-sol'.freeze
  DEFAULT_GATEWAY_ENDPOINT = 'https://proxy.ia.meusuper.app/v1'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      resolved_base = normalize_api_base(api_base.presence || openai_endpoint)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = resolved_base
      end

      yield context
    end

    def normalize_api_base(endpoint)
      ep = endpoint.presence || DEFAULT_GATEWAY_ENDPOINT
      clean_endpoint = ep.chomp('/')
      clean_endpoint.end_with?('/v1') ? clean_endpoint : "#{clean_endpoint}/v1"
    end

    def effective_api_key(account = nil)
      hook_key = account&.hooks&.find_by(app_id: 'openai', status: 'enabled')&.settings&.dig('api_key').presence
      hook_key || system_api_key
    end

    def effective_api_base
      normalize_api_base(openai_endpoint)
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = effective_api_base
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
      RubyLLM.models.load_from_json!
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence ||
        ENV.fetch('CAPTAIN_OPEN_AI_API_KEY', nil)
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence ||
        ENV.fetch('CAPTAIN_OPEN_AI_ENDPOINT', DEFAULT_GATEWAY_ENDPOINT)
    end
  end
end

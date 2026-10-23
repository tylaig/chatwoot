module Integrations::Openai::KeyValidator
  TIMEOUT_SECONDS = 5
  DEFAULT_GATEWAY_ENDPOINT = 'https://proxy.ia.meusuper.app/v1'.freeze

  def self.valid?(api_key)
    return false if api_key.blank?

    connection = Faraday.new do |f|
      f.options.timeout = TIMEOUT_SECONDS
      f.options.open_timeout = TIMEOUT_SECONDS
    end

    response = connection.get("#{api_base}/models") do |req|
      req.headers['Authorization'] = "Bearer #{api_key}"
    end

    response.status != 401
  rescue Faraday::Error => e
    Rails.logger.warn("[gateway-key-validator] #{e.class}: #{e.message}")
    true
  end

  def self.api_base
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence ||
               ENV.fetch('CAPTAIN_OPEN_AI_ENDPOINT', DEFAULT_GATEWAY_ENDPOINT)
    clean_endpoint = endpoint.chomp('/')
    clean_endpoint.end_with?('/v1') ? clean_endpoint : "#{clean_endpoint}/v1"
  end
end

# frozen_string_literal: true

require 'agents'
require 'ruby_llm'

module RubyLlmGatewayCompat
  module ToolsPatch
    def strip_strict(schema)
      return schema unless schema.is_a?(Hash)

      schema.each_with_object({}) do |(k, v), h|
        next if k.to_s == 'strict'

        h[k] = v.is_a?(Hash) ? strip_strict(v) : v
      end
    end

    def parameters_schema_for(tool)
      strip_strict(super)
    end
  end

  module MediaPatch
    def format_image(image)
      resolved_url = if image.url?
                       begin
                         image.for_llm
                       rescue StandardError => e
                         RubyLLM.logger.warn("Failed to inline image attachment as data URI, falling back to URL: #{e.message}")
                         image.source.to_s
                       end
                     else
                       image.for_llm
                     end

      {
        type: 'image_url',
        image_url: {
          url: resolved_url
        }
      }
    end
  end
end

RubyLLM::Providers::OpenAI.prepend(RubyLlmGatewayCompat::ToolsPatch)
RubyLLM::Providers::OpenAI::Tools.prepend(RubyLlmGatewayCompat::ToolsPatch)
RubyLLM::Providers::OpenAI::Tools.singleton_class.prepend(RubyLlmGatewayCompat::ToolsPatch)
RubyLLM::Providers::OpenAI.prepend(RubyLlmGatewayCompat::MediaPatch)
RubyLLM::Providers::OpenAI::Media.prepend(RubyLlmGatewayCompat::MediaPatch)
RubyLLM::Providers::OpenAI::Media.singleton_class.prepend(RubyLlmGatewayCompat::MediaPatch)

Rails.application.config.after_initialize do
  api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
  model = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || LlmConstants::DEFAULT_MODEL
  api_endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value || LlmConstants::OPENAI_API_ENDPOINT

  if api_key.present?
    Agents.configure do |config|
      config.openai_api_key = api_key
      if api_endpoint.present?
        clean_endpoint = api_endpoint.chomp('/')
        api_base = clean_endpoint.end_with?('/v1') ? clean_endpoint : "#{clean_endpoint}/v1"
        config.openai_api_base = api_base
      end
      config.default_model = model
      config.debug = false
    end
    Llm::Config.initialize!
  end
rescue StandardError => e
  Rails.logger.error "Failed to configure AI Agents SDK: #{e.message}"
end

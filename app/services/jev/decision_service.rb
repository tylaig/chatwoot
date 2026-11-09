# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Jev
  class DecisionService
    DEFAULT_MODEL = 'laya:multilingual'
    OPEN_TIMEOUT = 3.0
    READ_TIMEOUT = 15.0

    INTENT_LABELS = {
      'access_or_2fa_code' => 'Código 2FA / Acesso',
      'psn_2fa_code' => 'Código 2FA PSN/Xbox',
      'technical_issue' => 'Suporte Técnico / Licença',
      'license_lock_issue' => 'Cadeado / Licença PS4-PS5',
      'refund_or_cancellation' => 'Pedido de Reembolso',
      'refund_request' => 'Pedido de Reembolso',
      'pre_sale_commercial' => 'Dúvida Pré-Venda / Comercial',
      'pre_sale_question' => 'Dúvida Pré-Compra',
      'general_support' => 'Atendimento Geral'
    }.freeze

    class << self
      def endpoint_base
        ENV.fetch('JEV_OLLAYA_URL') do
          ENV.fetch('OLLAYA_URL', 'http://ollaya_jev:11435')
        end
      end

      def model_name
        ENV.fetch('JEV_MODEL', DEFAULT_MODEL)
      end

      def status
        uri = URI.join(endpoint_base, '/api/version')
        res = http_get(uri)
        return { online: false, error: 'unreachable' } unless res.is_a?(Net::HTTPSuccess)

        version_data = JSON.parse(res.body) rescue {}
        tags_res = http_get(URI.join(endpoint_base, '/api/tags'))
        tags_data = tags_res.is_a?(Net::HTTPSuccess) ? (JSON.parse(tags_res.body) rescue {}) : {}
        presets_res = http_get(URI.join(endpoint_base, '/api/presets'))
        presets_data = presets_res.is_a?(Net::HTTPSuccess) ? (JSON.parse(presets_res.body) rescue {}) : {}

        {
          online: true,
          endpoint: endpoint_base,
          version: version_data['version'] || '0.18.0',
          default_model: model_name,
          models: Array(tags_data['models']).map { |m| { name: m['name'], size: m['size'], quantization: m.dig('details', 'quantization_level') } },
          presets: Array(presets_data['presets']).map { |p| { name: p['name'], description: p['description'], builtin: p['builtin'] } }
        }
      rescue StandardError => e
        { online: false, endpoint: endpoint_base, error: e.message }
      end

      def triage_message(text, preset: 'msc_saas_triage')
        clean = text.to_s.strip
        return nil if clean.length < 3

        raw = decide_with_preset(state: clean, preset: preset)
        return nil unless raw && raw['answers'].is_a?(Hash)

        answers = raw['answers']
        intent_ans = answers['intent'] || {}
        urgency_ans = answers['urgency'] || {}
        refund_ans = answers['refund_requested'] || {}
        handoff_ans = answers['needs_human_handoff'] || {}

        intent_key = intent_ans['choice'].to_s
        eval_ms = (raw['eval_duration'].to_f / 1_000_000.0).round(1)

        {
          'intent' => intent_key,
          'intent_label' => INTENT_LABELS[intent_key] || intent_key.tr('_', ' ').capitalize,
          'intent_confidence' => intent_ans['confidence'].to_f.round(4),
          'intent_probabilities' => intent_ans['probabilities'] || {},
          'urgency_score' => urgency_ans['score'].to_f.round(2),
          'urgency_confidence' => urgency_ans['confidence'].to_f.round(4),
          'urgency_probabilities' => urgency_ans['probabilities'] || {},
          'refund_requested' => refund_ans['noul'].to_f.round(4),
          'needs_human_handoff' => handoff_ans['noul'].to_f.round(4),
          'latency_ms' => eval_ms,
          'output_tokens' => raw.dig('usage', 'output_tokens') || 0,
          'input_tokens' => raw.dig('usage', 'input_tokens') || 0,
          'model' => raw['model'] || model_name,
          'preset' => preset,
          'evaluated_at' => Time.current.iso8601
        }
      rescue StandardError => e
        Rails.logger.warn("[JEV][DecisionService] triage_message failed: #{e.message}")
        nil
      end

      def check_captain_handoff_guard(text)
        clean = text.to_s.strip
        return nil if clean.length < 8

        raw = decide_with_preset(state: clean, preset: 'captain_handoff_guard')
        return nil unless raw && raw['answers'].is_a?(Hash)

        answers = raw['answers']
        promised = answers.dig('promised_human_transfer', 'noul').to_f.round(4)
        wait_agent = answers.dig('asked_customer_to_wait_for_agent', 'noul').to_f.round(4)
        eval_ms = (raw['eval_duration'].to_f / 1_000_000.0).round(1)

        {
          'promised_human_transfer' => promised,
          'asked_customer_to_wait_for_agent' => wait_agent,
          'enforced' => promised >= 0.85,
          'latency_ms' => eval_ms,
          'output_tokens' => raw.dig('usage', 'output_tokens') || 0,
          'model' => raw['model'] || model_name,
          'evaluated_at' => Time.current.iso8601
        }
      rescue StandardError => e
        Rails.logger.warn("[JEV][DecisionService] check_captain_handoff_guard failed: #{e.message}")
        nil
      end

      def decide_with_preset(state:, preset:, model: model_name)
        preset_info = fetch_preset_questions(preset)
        return nil if preset_info.blank?

        decide(state: state, questions: preset_info, model: model)
      end

      def decide(state:, questions:, model: model_name)
        uri = URI.join(endpoint_base, '/api/decide')
        payload = {
          model: model,
          state: state,
          questions: questions,
          keep_alive: '24h'
        }
        res = http_post(uri, payload)
        return nil unless res.is_a?(Net::HTTPSuccess)

        JSON.parse(res.body)
      rescue StandardError => e
        Rails.logger.warn("[JEV][DecisionService] decide error: #{e.message}")
        nil
      end

      private

      def fetch_preset_questions(preset_name)
        @preset_cache ||= {}
        return @preset_cache[preset_name] if @preset_cache[preset_name].present?

        uri = URI.join(endpoint_base, '/api/presets/show')
        res = http_post(uri, { name: preset_name })
        if res.is_a?(Net::HTTPSuccess)
          body = JSON.parse(res.body) rescue {}
          questions = body['questions']
          @preset_cache[preset_name] = questions if questions.is_a?(Hash) && questions.any?
          return @preset_cache[preset_name]
        end

        fallback_preset_questions(preset_name)
      rescue StandardError
        fallback_preset_questions(preset_name)
      end

      def fallback_preset_questions(preset_name)
        if preset_name == 'captain_handoff_guard'
          {
            'promised_human_transfer' => {
              'type' => 'noul',
              'instructions' => 'Does the assistant message promise or state that it is transferring the customer to a human agent, specialist, or support queue?'
            },
            'asked_customer_to_wait_for_agent' => {
              'type' => 'noul',
              'instructions' => 'Does the assistant tell the customer to wait for a human attendant to reply?'
            }
          }
        else
          {
            'intent' => {
              'type' => 'choice',
              'instructions' => 'What is the customer main request or intent in this support/sales conversation?',
              'criteria' => {
                'access_or_2fa_code' => 'Asking for login credentials, 2FA verification code, or account access',
                'technical_issue' => 'Reporting a bug, padlock/license error, system failure, or technical problem',
                'refund_or_cancellation' => 'Demanding a refund, chargeback, PIX return, or subscription/order cancellation',
                'pre_sale_commercial' => 'Asking about pricing, plans, features, delivery, or how to buy/subscribe',
                'general_support' => 'General greeting, status check, or routine customer support question'
              }
            },
            'urgency' => {
              'type' => 'score',
              'instructions' => 'How urgent and frustrated is the customer?',
              'criteria' => [
                'Calm, polite question with no frustration',
                'Normal support request waiting for instructions or reply',
                'Impatient, complaining about delay or unresolved issue',
                'Angry, demanding immediate refund or threatening legal/complaint action'
              ]
            },
            'refund_requested' => {
              'type' => 'noul',
              'instructions' => 'Is the customer asking for a refund, money back, or cancellation?'
            },
            'needs_human_handoff' => {
              'type' => 'noul',
              'instructions' => 'Should this conversation be immediately transferred to a human support agent?'
            }
          }
        end
      end

      def http_get(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end
      end

      def http_post(uri, body_hash)
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body_hash)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(req)
        end
      end
    end
  end
end

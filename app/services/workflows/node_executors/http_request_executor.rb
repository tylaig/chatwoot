# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'ipaddr'
require 'resolv'

module Workflows
  module NodeExecutors
    class HttpRequestExecutor < BaseExecutor
      BLOCKED_HOSTS = ['localhost', '127.0.0.1', '0.0.0.0', '169.254.169.254'].freeze
      SENSITIVE_HEADERS = %w[authorization proxy-authorization x-api-key api-key token secret].freeze
      MAX_ATTEMPTS = 3
      MAX_TIMEOUT = 20
      MAX_RETRY_INTERVAL = 5

      def self.probe(config_hash)
        node = { 'config' => config_hash }
        new(execution: nil, node: node, version: nil).probe
      end

      def execute
        result = dispatch
        return failure_result(result[:error]) if result[:error].present? && result[:status].nil?

        success = result[:status].to_i.between?(200, 299)
        handle = success ? 'SUCCESS' : 'ERROR'
        targets = version ? next_nodes(handle) : []

        store_response(result)

        if !success && targets.empty?
          return {
            status: 'failed',
            error: result[:error].presence || "HTTP status #{result[:status]}",
            output: result_output(result, handle),
            next_nodes: []
          }
        end

        {
          status: 'success',
          output: result_output(result, handle),
          next_nodes: targets
        }
      rescue StandardError => e
        failure_result("Falha na requisição HTTP: #{e.message}")
      end

      def probe
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = dispatch
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        success = result[:status].to_i.between?(200, 299)

        {
          ok: success,
          status: result[:status],
          statusText: success ? "#{result[:status]} OK" : (result[:error].presence || "HTTP #{result[:status]}"),
          duration: "#{duration_ms} ms",
          data: result[:body]
        }
      rescue StandardError => e
        { ok: false, statusText: e.message, duration: '—', data: { error: e.message } }
      end

      private

      def dispatch
        raw_url = resolve_vars(config[:url].to_s)
        raise 'Informe a URL da requisição.' if raw_url.blank?

        uri = URI.parse(raw_url)
        raise 'Endereço de rede privada ou local bloqueado por segurança SSRF.' if private_or_blocked_host?(uri.host)

        apply_query!(uri)
        method = (config[:method] || 'POST').upcase
        headers = request_headers
        timeout_seconds = timeout_limit
        attempts = attempt_limit

        response = nil
        attempts.times do |index|
          response = perform_request(uri, method, headers, timeout_seconds)
          break if response.code.to_i < 500
          break if index == attempts - 1

          sleep(retry_interval)
        end

        parsed_body = parse_body(response.body)
        code = response.code.to_i
        {
          status: code,
          body: parsed_body,
          headers: headers,
          error: code.between?(200, 299) ? nil : "HTTP status #{code}"
        }
      end

      def perform_request(uri, method, headers, timeout_seconds)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = timeout_seconds
        http.read_timeout = timeout_seconds

        req_class = {
          'GET' => Net::HTTP::Get,
          'POST' => Net::HTTP::Post,
          'PUT' => Net::HTTP::Put,
          'PATCH' => Net::HTTP::Patch,
          'DELETE' => Net::HTTP::Delete
        }.fetch(method, Net::HTTP::Post)

        req = req_class.new(uri.request_uri)
        headers.each { |key, value| req[key] = resolve_vars(value.to_s) }

        body = config[:body].presence || config[:payload].presence
        if %w[POST PUT PATCH].include?(method) && body.present?
          req.body = resolve_vars(body.is_a?(Hash) ? body.to_json : body.to_s)
          req['Content-Type'] ||= 'application/json'
        end

        http.request(req)
      end

      def request_headers
        headers = normalize_pairs(config[:headers])
        token = config[:auth_token].to_s
        usable_token = token.present? && !token.match?(/\A\*+\z/)

        case config[:auth_type].to_s
        when 'bearer'
          headers['Authorization'] ||= "Bearer #{token}" if usable_token
        when 'api_key'
          headers['X-API-Key'] ||= token if usable_token
        when 'basic'
          headers['Authorization'] ||= "Basic #{token}" if usable_token
        end

        headers
      end

      def apply_query!(uri)
        pairs = normalize_pairs(config[:params])
        return if pairs.blank?

        query = URI.decode_www_form(uri.query || '')
        pairs.each { |key, value| query << [key, resolve_vars(value.to_s)] }
        uri.query = URI.encode_www_form(query)
      end

      def normalize_pairs(raw)
        case raw
        when Array
          raw.each_with_object({}) do |item, acc|
            pair = item.respond_to?(:with_indifferent_access) ? item.with_indifferent_access : {}
            key = pair[:key].to_s
            acc[key] = pair[:value] if key.present?
          end
        when Hash
          raw.transform_keys(&:to_s)
        else
          {}
        end
      end

      def store_response(result)
        return if execution.blank?

        payload = { 'status' => result[:status], 'body' => result[:body] }
        ctx = (execution.context || {}).dup
        key = config[:save_response_as].presence || 'http_response'
        ctx[key] = payload
        ctx['http_response'] = payload
        variables = (execution.variables || {}).merge(key.sub(/\A(workflow|vars?)\./, '') => payload)
        execution.update!(context: ctx, variables: variables)
        apply_response_mappings!(result[:body])
      end

      def apply_response_mappings!(body)
        variables = (execution.variables || {}).dup
        Array(config[:response_mappings]).each do |raw|
          row = raw.is_a?(Hash) ? raw.with_indifferent_access : {}
          next if row[:path].blank?

          value = dig_path(body, row[:path])
          case row[:destination].to_s
          when 'contact'
            write_mapped_attribute(execution.contact, 'contact_attribute', row[:attribute_key], value)
          when 'conversation'
            write_mapped_attribute(execution.conversation, 'conversation_attribute', row[:attribute_key], value)
          else
            name = row[:variable_name].to_s.strip.delete_prefix('vars.')
            variables[name] = mapped_variable_value(value) if name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          end
        end
        execution.update!(variables: variables)
      end

      def write_mapped_attribute(record, model, key, value)
        return if record.blank? || key.blank?

        definition = execution.account.custom_attribute_definitions.find_by(attribute_model: model, attribute_key: key)
        return if definition.blank?

        coerced = coerce_mapped_value(definition.attribute_display_type, value)
        record.update!(custom_attributes: (record.custom_attributes || {}).merge(key => coerced))
      end

      def coerce_mapped_value(display_type, value)
        case display_type
        when 'number', 'currency', 'percent'
          value.to_s.tr(',', '.').to_f
        when 'checkbox'
          ActiveModel::Type::Boolean.new.cast(value)
        else
          value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
        end
      end

      def mapped_variable_value(value)
        return '' if value.nil?
        return value if value.is_a?(Numeric) || value.in?([true, false]) || value.is_a?(String)

        value.to_json
      end

      def dig_path(data, path)
        path.to_s.split('.').reduce(data) do |current, key|
          case current
          when Hash
            if current.key?(key)
              current[key]
            elsif current.key?(key.to_sym)
              current[key.to_sym]
            end
          when Array
            key.match?(/\A\d+\z/) ? current[key.to_i] : nil
          end
        end
      end

      def result_output(result, handle)
        {
          status_code: result[:status],
          response_body: result[:body],
          branch: handle,
          safe_headers: redact_headers(result[:headers] || {}),
          error: result[:error]
        }
      end

      def failure_result(message)
        targets = version ? next_nodes('ERROR') : []
        if targets.any?
          return {
            status: 'success',
            output: { error: message, branch: 'ERROR' },
            next_nodes: targets
          }
        end

        { status: 'failed', error: message, next_nodes: [] }
      end

      def timeout_limit
        value = (config[:timeout] || 10).to_i
        value = 10 if value <= 0
        [value, MAX_TIMEOUT].min
      end

      def attempt_limit
        value = (config[:retry_count] || 1).to_i
        value = 1 if value <= 0
        [value, MAX_ATTEMPTS].min
      end

      def retry_interval
        value = (config[:retry_interval] || 0).to_i
        [[value, 0].max, MAX_RETRY_INTERVAL].min
      end

      def parse_body(body)
        JSON.parse(body.to_s)
      rescue StandardError
        body.to_s[0..2000]
      end

      def private_or_blocked_host?(host)
        return true if host.blank?

        lower_host = host.downcase
        return true if BLOCKED_HOSTS.include?(lower_host)
        return true if lower_host.end_with?('.internal', '.local', 'localhost')

        ips = begin
          Resolv.getaddresses(host)
        rescue StandardError
          []
        end
        return true if ips.empty? && host.match?(/^\d+\.\d+\.\d+\.\d+$/)

        ips.any? do |ip_str|
          ip = IPAddr.new(ip_str)
          ip.loopback? ||
            ip.private? ||
            ip.link_local? ||
            IPAddr.new('169.254.0.0/16').include?(ip) ||
            IPAddr.new('100.64.0.0/10').include?(ip) ||
            IPAddr.new('0.0.0.0/8').include?(ip)
        rescue StandardError
          true
        end
      rescue StandardError
        true
      end

      def redact_headers(headers)
        headers.each_with_object({}) do |(key, value), acc|
          acc[key] = SENSITIVE_HEADERS.include?(key.downcase) ? '[REDACTED]' : value
        end
      end
    end
  end
end

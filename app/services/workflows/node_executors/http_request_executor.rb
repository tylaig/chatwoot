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

      def execute
        raw_url = resolve_vars(config[:url].to_s)
        method = (config[:method] || 'POST').upcase
        headers = (config[:headers] || {}).transform_keys(&:to_s)
        timeout_seconds = (config[:timeout] || 10).to_i

        uri = URI.parse(raw_url)

        if private_or_blocked_host?(uri.host)
          return { status: 'failed', error: 'Endereço de rede privada ou local bloqueado por segurança SSRF.' }
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = timeout_seconds
        http.read_timeout = timeout_seconds

        req_class = case method
                    when 'GET' then Net::HTTP::Get
                    when 'POST' then Net::HTTP::Post
                    when 'PUT' then Net::HTTP::Put
                    when 'PATCH' then Net::HTTP::Patch
                    when 'DELETE' then Net::HTTP::Delete
                    else Net::HTTP::Post
                    end

        req = req_class.new(uri.request_uri)
        headers.each { |k, v| req[k] = resolve_vars(v.to_s) }

        if %w[POST PUT PATCH].include?(method) && config[:body].present?
          req.body = resolve_vars(config[:body].is_a?(Hash) ? config[:body].to_json : config[:body].to_s)
          req['Content-Type'] ||= 'application/json'
        end

        response = http.request(req)
        parsed_body = begin
          JSON.parse(response.body)
        rescue StandardError
          response.body.to_s[0..2000]
        end

        # Store in execution context
        ctx = execution.context || {}
        ctx['http_response'] = {
          'status' => response.code.to_i,
          'body' => parsed_body
        }
        execution.update!(context: ctx)

        is_success = response.code.to_i.between?(200, 299)
        handle = is_success ? 'success' : 'error'

        target_nodes = next_nodes(handle)
        target_nodes = next_nodes if target_nodes.empty?

        {
          status: is_success ? 'success' : 'failed',
          output: {
            status_code: response.code.to_i,
            response_body: parsed_body,
            safe_headers: redact_headers(headers)
          },
          next_nodes: target_nodes,
          error: is_success ? nil : "HTTP status #{response.code}"
        }
      rescue StandardError => e
        {
          status: 'failed',
          error: "Falha na requisição HTTP: #{e.message}",
          next_nodes: next_nodes('error')
        }
      end

      private

      def private_or_blocked_host?(host)
        return true if host.blank?
        lower_host = host.downcase
        return true if BLOCKED_HOSTS.include?(lower_host)
        return true if lower_host.end_with?('.internal', '.local', 'localhost')

        # Check IP ranges
        ips = Resolv.getaddresses(host) rescue []
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
        headers.each_with_object({}) do |(k, v), acc|
          acc[k] = SENSITIVE_HEADERS.include?(k.downcase) ? '[REDACTED]' : v
        end
      end
    end
  end
end

# frozen_string_literal: true

module Evolution
  class Client
    class Error < StandardError
      attr_reader :status

      def initialize(message, status = nil)
        @status = status
        super(message)
      end
    end

    TIMEOUT = 8
    BODY_LIMIT = 1_000_000
    EVENTS = %w[
      QRCODE_UPDATED CONNECTION_UPDATE MESSAGES_UPSERT MESSAGES_UPDATE
      MESSAGES_DELETE SEND_MESSAGE CONTACTS_UPDATE CHATS_UPDATE
      GROUPS_UPSERT GROUP_PARTICIPANTS_UPDATE PRESENCE_UPDATE
    ].freeze

    def initialize(base_url:, api_key:)
      @base_url = self.class.normalize_url(base_url)
      @api_key = api_key.to_s.strip
    end

    def self.normalize_url(value)
      raw = value.to_s.strip.chomp('/')
      uri = URI.parse(raw)
      unless uri.is_a?(URI::HTTP) && uri.host.present?
        raise Error, 'Informe uma URL que comece com http:// ou https://.'
      end
      raise Error, 'A URL não pode conter usuário ou senha.' if uri.userinfo.present?

      "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless [80, 443].include?(uri.port)}#{uri.path.chomp('/')}"
    rescue URI::InvalidURIError
      raise Error, 'A URL da Evolution API é inválida.'
    end

    def precheck
      checks = [{ id: 'url', ok: true, label: 'URL', detail: @base_url }]
      info = {}
      count = 0
      begin
        info = server_info
        checks << reach_check(info)
      rescue Error => e
        checks << { id: 'version', ok: false, label: 'Versão', detail: e.message }
        return result(false, checks)
      end
      return result(false, checks, info) unless checks.last[:ok]
      if @api_key.blank?
        checks << { id: 'key', ok: false, label: 'Chave de API', detail: 'Informe a chave global da Evolution.' }
        return result(false, checks, info)
      end

      begin
        listed = instances
        count = listed.size
        checks << key_check(listed)
      rescue Error => e
        checks << { id: 'key', ok: false, label: 'Chave de API', detail: e.message }
      end
      result(checks.all? { |check| check[:ok] }, checks, info, count)
    end

    def instances
      extract_list(request(:get, 'instance/fetchInstances'))
        .filter_map { |item| normalize_instance(item) }
    end

    def create_instance(name:, number: nil)
      body = { instanceName: name, integration: 'WHATSAPP-BAILEYS', qrcode: true }
      body[:number] = number if number.present?
      request(:post, 'instance/create', body)
    end

    def connect(name)
      payload = request(:get, "instance/connect/#{encode(name)}")
      qr = payload.is_a?(Hash) ? (payload['qrcode'].is_a?(Hash) ? payload['qrcode'] : payload) : {}
      image = qr['base64'].presence || payload['base64']
      image = "data:image/png;base64,#{image}" if image.present? && !image.start_with?('data:')
      {
        base64: image,
        pairing_code: qr['pairingCode'].presence || payload['pairingCode'],
        code: qr['code'].presence || payload['code']
      }
    end

    def connection_state(name)
      payload = request(:get, "instance/connectionState/#{encode(name)}")
      state = payload.is_a?(Hash) ? (payload.dig('instance', 'state') || payload['state'] || payload['status']) : nil
      { state: state.to_s }
    end

    def logout(name)
      request(:delete, "instance/logout/#{encode(name)}")
    end

    def restart(name)
      request(:put, "instance/restart/#{encode(name)}")
    end

    def delete_instance(name)
      request(:delete, "instance/delete/#{encode(name)}")
    end

    def find_webhook(name)
      payload = request(:get, "webhook/find/#{encode(name)}")
      webhook = payload.is_a?(Hash) ? (payload['webhook'].is_a?(Hash) ? payload['webhook'] : payload) : {}
      {
        enabled: ActiveModel::Type::Boolean.new.cast(webhook['enabled']),
        url: webhook['url'].to_s,
        events: Array(webhook['events'])
      }
    rescue Error => e
      return { enabled: false, url: '', events: [] } if e.status == 404

      raise
    end

    def set_webhook(name, enabled:, url:, events:)
      request(:post, "webhook/set/#{encode(name)}", { enabled: enabled, url: url, events: events, base64: false })
    end

    private

    def server_info
      payload = request(:get, '')
      version = payload['version'] || payload['serverVersion'] if payload.is_a?(Hash)
      client_name = payload['clientName'] || payload['client'] if payload.is_a?(Hash)
      { version: version.to_s, client_name: client_name.to_s, payload: payload }
    end

    def reach_check(info)
      version = info[:version].presence
      unless version
        return { id: 'version', ok: false, label: 'Versão', detail: 'A resposta não trouxe a versão da Evolution API.' }
      end

      major = version.split('.').first.to_i
      detail = "Evolution API #{version}"
      detail = "#{detail}. Esta tela foi feita para a versão 2." if major.positive? && major < 2
      { id: 'version', ok: true, label: 'Versão', detail: detail, warning: major.positive? && major < 2 }
    end

    def key_check(listed)
      return { id: 'key', ok: false, label: 'Chave de API', detail: 'Informe a chave global da Evolution.' } if @api_key.blank?

      { id: 'key', ok: true, label: 'Chave de API', detail: "#{listed.size} instância(s) encontrada(s)." }
    end

    def result(ok, checks, info = {}, count = 0)
      {
        ok: ok,
        error: ok ? nil : checks.reverse.find { |check| !check[:ok] }&.dig(:detail),
        checks: checks,
        version: info[:version].to_s,
        client_name: info[:client_name].to_s,
        instance_count: count
      }
    end

    def extract_list(payload)
      return payload if payload.is_a?(Array)
      return payload['instances'] if payload.is_a?(Hash) && payload['instances'].is_a?(Array)
      return [payload] if payload.is_a?(Hash) && (payload['instanceName'] || payload['name'] || payload['instance'])

      []
    end

    def normalize_instance(item)
      data = item.is_a?(Hash) ? item : {}
      nested = data['instance'].is_a?(Hash) ? data['instance'] : {}
      merged = nested.merge(data.except('instance'))
      name = merged['instanceName'] || merged['name']
      return if name.blank?

      owner = (merged['ownerJid'] || merged['owner'] || merged['number']).to_s.split('@').first
      {
        name: name,
        status: (merged['connectionStatus'] || merged['status'] || merged['state']).to_s,
        owner: owner,
        profile_name: merged['profileName'].to_s,
        profile_picture: (merged['profilePicUrl'] || merged['profilePictureUrl']).to_s,
        integration: (merged['integration'] || nested['integration']).to_s
      }
    end

    def request(method, path, body = nil)
      uri = URI.parse(path.present? ? "#{@base_url}/#{path}" : @base_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http_request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
      http_request['apikey'] = @api_key if @api_key.present?
      http_request['Accept'] = 'application/json'
      if body
        http_request['Content-Type'] = 'application/json'
        http_request.body = body.to_json
      end

      response = http.request(http_request)
      parsed = parse_body(response.body.to_s)
      return parsed if response.is_a?(Net::HTTPSuccess)

      raise Error.new(failure_message(parsed, response.code), response.code.to_i)
    rescue Error
      raise
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Error, 'A Evolution API demorou demais para responder.'
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      raise Error, 'Não foi possível alcançar a URL da Evolution API.'
    rescue OpenSSL::SSL::SSLError
      raise Error, 'A conexão TLS com a Evolution API falhou.'
    end

    def parse_body(raw)
      raise Error, 'A resposta da Evolution API passou do tamanho esperado.' if raw.bytesize > BODY_LIMIT
      return {} if raw.blank?
      return JSON.parse(raw) if raw.lstrip.start_with?('{', '[')

      raise Error, 'A URL respondeu, mas não é o JSON da Evolution API.'
    rescue JSON::ParserError
      raise Error, 'A Evolution API devolveu um JSON inválido.'
    end

    def failure_message(parsed, code)
      message = parsed.dig('error', 'message') if parsed.is_a?(Hash)
      message ||= parsed['message'] if parsed.is_a?(Hash) && parsed['message'].is_a?(String)
      return 'A chave de API foi recusada.' if %w[401 403].include?(code.to_s)

      message.presence || "A Evolution API respondeu com erro #{code}."
    end

    def encode(name)
      ERB::Util.url_encode(name.to_s)
    end
  end
end

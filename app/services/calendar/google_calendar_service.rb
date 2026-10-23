# frozen_string_literal: true

class Calendar::GoogleCalendarService
  GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
  GOOGLE_API_BASE = 'https://www.googleapis.com/calendar/v3'
  GOOGLE_USERINFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'
  SCOPES = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly'
  ].join(' ').freeze

  def initialize(schedule)
    @schedule = schedule
  end

  def self.oauth_configured?(account = nil)
    client_id(account).present? && client_secret(account).present?
  end

  def self.account_oauth_config(account)
    return {} unless account

    raw = account.respond_to?(:custom_attributes) ? (account.custom_attributes || {}) : {}
    cfg = raw['google_calendar_oauth']
    cfg.is_a?(Hash) ? cfg : {}
  end

  def self.client_id(account = nil, hook: nil)
    hook_cid = hook&.settings&.dig('oauth_client_id')
    return hook_cid if hook_cid.present?

    acc_cid = account_oauth_config(account)['client_id']
    return acc_cid if acc_cid.present?

    GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil).presence || ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil)
  end

  def self.client_secret(account = nil, hook: nil)
    hook_sec = hook&.settings&.dig('oauth_client_secret')
    return hook_sec if hook_sec.present?

    acc_sec = account_oauth_config(account)['client_secret']
    return acc_sec if acc_sec.present?

    GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil).presence || ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil)
  end

  def self.redirect_uri
    base = ENV.fetch('FRONTEND_URL', 'https://chat.meusuper.app').sub(%r{/+$}, '')
    "#{base}/callbacks/google_calendar"
  end

  def self.authorization_url(state:, account: nil, hook: nil)
    params = {
      client_id: client_id(account, hook: hook),
      redirect_uri: redirect_uri,
      response_type: 'code',
      scope: SCOPES,
      access_type: 'offline',
      prompt: 'consent',
      include_granted_scopes: 'true',
      state: state
    }
    "#{GOOGLE_AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def self.exchange_code!(code, account: nil, hook: nil)
    resp = HTTParty.post(
      GOOGLE_TOKEN_URL,
      body: {
        code: code,
        client_id: client_id(account, hook: hook),
        client_secret: client_secret(account, hook: hook),
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      },
      timeout: 15
    )
    raise "Falha OAuth Google (#{resp.code}): #{resp.body}" unless resp.success?

    tokens = resp.parsed_response
    user_resp = HTTParty.get(
      GOOGLE_USERINFO_URL,
      headers: { 'Authorization' => "Bearer #{tokens['access_token']}" },
      timeout: 10
    )
    email = user_resp.success? ? user_resp.parsed_response['email'] : nil

    {
      'access_token' => tokens['access_token'],
      'refresh_token' => tokens['refresh_token'],
      'expires_at' => (Time.current + tokens['expires_in'].to_i.seconds).to_i,
      'email' => email
    }
  end

  # Returns array of [Time(start), Time(end)] busy ranges from Google Calendar freeBusy API
  def busy_intervals(window_start, window_end)
    return [] unless @schedule.google_connected?

    token = valid_access_token
    return [] if token.blank?

    cal_id = @schedule.google_calendar_id.presence || 'primary'
    resp = HTTParty.post(
      "#{GOOGLE_API_BASE}/freeBusy",
      headers: auth_headers(token),
      body: {
        timeMin: window_start.utc.iso8601,
        timeMax: window_end.utc.iso8601,
        timeZone: @schedule.timezone,
        items: [{ id: cal_id }]
      }.to_json,
      timeout: 10
    )
    return [] unless resp.success?

    busy_list = resp.parsed_response.dig('calendars', cal_id, 'busy') || []
    busy_list.filter_map do |entry|
      s = Time.iso8601(entry['start']) rescue nil
      e = Time.iso8601(entry['end']) rescue nil
      [s, e] if s && e && e > s
    end
  rescue StandardError => e
    Rails.logger.warn("[Calendar::GoogleCalendarService] freeBusy fallback for schedule #{@schedule.id}: #{e.message}")
    []
  end

  def create_event(appointment)
    unless @schedule.google_connected? && valid_access_token.present?
      return fallback_meeting_details(appointment)
    end

    token = valid_access_token
    cal_id = CGI.escape(@schedule.google_calendar_id.presence || 'primary')
    payload = build_event_payload(appointment)
    query = appointment.location_type == 'google_meet' ? '?conferenceDataVersion=1&sendUpdates=all' : '?sendUpdates=all'

    resp = HTTParty.post(
      "#{GOOGLE_API_BASE}/calendars/#{cal_id}/events#{query}",
      headers: auth_headers(token),
      body: payload.to_json,
      timeout: 15
    )

    if resp.success?
      data = resp.parsed_response
      meet_link = data['hangoutLink'].presence ||
                  data.dig('conferenceData', 'entryPoints')&.find { |ep| ep['entryPointType'] == 'video' }&.dig('uri')
      {
        google_event_id: data['id'],
        google_calendar_id: @schedule.google_calendar_id.presence || 'primary',
        meeting_url: meet_link.presence || fallback_meet_url(appointment)
      }
    else
      Rails.logger.warn("[Calendar::GoogleCalendarService] create_event non-200 (#{resp.code}): #{resp.body}")
      fallback_meeting_details(appointment)
    end
  rescue StandardError => e
    Rails.logger.warn("[Calendar::GoogleCalendarService] create_event error: #{e.message}")
    fallback_meeting_details(appointment)
  end

  def update_event(appointment)
    return false unless @schedule.google_connected? && appointment.google_event_id.present?

    token = valid_access_token
    return false if token.blank?

    cal_id = CGI.escape(appointment.google_calendar_id.presence || @schedule.google_calendar_id.presence || 'primary')
    event_id = CGI.escape(appointment.google_event_id)

    if appointment.status == 'cancelled'
      resp = HTTParty.delete(
        "#{GOOGLE_API_BASE}/calendars/#{cal_id}/events/#{event_id}?sendUpdates=all",
        headers: auth_headers(token),
        timeout: 12
      )
      return resp.success? || resp.code == 410
    end

    resp = HTTParty.patch(
      "#{GOOGLE_API_BASE}/calendars/#{cal_id}/events/#{event_id}?sendUpdates=all",
      headers: auth_headers(token),
      body: build_event_payload(appointment, include_conference: false).to_json,
      timeout: 12
    )
    resp.success?
  rescue StandardError => e
    Rails.logger.warn("[Calendar::GoogleCalendarService] update_event error: #{e.message}")
    false
  end

  private

  def auth_headers(token)
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  def valid_access_token
    creds = @schedule.google_credentials || {}
    access_token = creds['access_token']
    refresh_token = creds['refresh_token']
    expires_at = creds['expires_at'].to_i

    return nil if access_token.blank? && refresh_token.blank?
    return access_token if access_token.present? && expires_at > (Time.current.to_i + 60)
    return access_token if refresh_token.blank?

    resp = HTTParty.post(
      GOOGLE_TOKEN_URL,
      body: {
        client_id: self.class.client_id(@schedule.account),
        client_secret: self.class.client_secret(@schedule.account),
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
      },
      timeout: 12
    )
    return nil unless resp.success?

    data = resp.parsed_response
    updated = creds.merge(
      'access_token' => data['access_token'],
      'expires_at' => (Time.current + data['expires_in'].to_i.seconds).to_i
    )
    @schedule.update_columns(google_credentials: updated)
    data['access_token']
  rescue StandardError => e
    Rails.logger.warn("[Calendar::GoogleCalendarService] refresh token error: #{e.message}")
    nil
  end

  def build_event_payload(appointment, include_conference: true)
    attendees = []
    attendees << { email: appointment.customer_email, displayName: appointment.customer_name } if appointment.customer_email.present?

    description_lines = [
      "Cliente: #{appointment.customer_name}",
      ("Telefone/WhatsApp: #{appointment.customer_phone}" if appointment.customer_phone.present?),
      ("E-mail: #{appointment.customer_email}" if appointment.customer_email.present?),
      ("Origem: #{appointment.source}" if appointment.source.present?),
      ("Observações: #{appointment.notes}" if appointment.notes.present?),
      "Gerenciado via Meu Super Chat (#{ENV.fetch('FRONTEND_URL', 'https://chat.meusuper.app')})"
    ].compact

    payload = {
      summary: "#{appointment.title} — #{appointment.customer_name}",
      description: description_lines.join("\n"),
      start: {
        dateTime: appointment.starts_at.in_time_zone(@schedule.timezone).iso8601,
        timeZone: @schedule.timezone
      },
      end: {
        dateTime: appointment.ends_at.in_time_zone(@schedule.timezone).iso8601,
        timeZone: @schedule.timezone
      },
      attendees: attendees
    }

    if include_conference && appointment.location_type == 'google_meet'
      payload[:conferenceData] = {
        createRequest: {
          requestId: "msc-#{appointment.uid || SecureRandom.hex(6)}",
          conferenceSolutionKey: { type: 'hangoutsMeet' }
        }
      }
    end

    payload
  end

  def fallback_meeting_details(appointment)
    {
      google_event_id: nil,
      google_calendar_id: nil,
      meeting_url: fallback_meet_url(appointment)
    }
  end

  def fallback_meet_url(appointment)
    return appointment.meeting_url if appointment.meeting_url.present?
    return nil unless appointment.location_type == 'google_meet'

    base = ENV.fetch('FRONTEND_URL', 'https://chat.meusuper.app').sub(%r{/+$}, '')
    "#{base}/agendar/sala/#{appointment.uid || SecureRandom.alphanumeric(8).downcase}"
  end
end

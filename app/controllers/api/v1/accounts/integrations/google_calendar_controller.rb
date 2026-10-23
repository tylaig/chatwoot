# frozen_string_literal: true

class Api::V1::Accounts::Integrations::GoogleCalendarController < Api::V1::Accounts::Integrations::BaseController
  before_action :check_authorization
  before_action :fetch_hook, only: [:update_hook, :test_connection, :sync_events, :destroy]

  def index
    ensure_hooks_bootstrapped_from_schedules!
    hooks = Current.account.hooks.where(app_id: 'google_calendar').order(:id)
    oauth_cfg = Calendar::GoogleCalendarService.account_oauth_config(Current.account)

    render json: {
      hooks: hooks.map { |h| serialize_hook(h) },
      oauth_configured: Calendar::GoogleCalendarService.oauth_configured?(Current.account),
      oauth_client_id: oauth_cfg['client_id'].presence || (Calendar::GoogleCalendarService.client_id(Current.account).present? ? 'configured_globally' : ''),
      has_custom_oauth_credentials: oauth_cfg['client_id'].present? && oauth_cfg['client_secret'].present?,
      redirect_uri: Calendar::GoogleCalendarService.redirect_uri,
      schedules: Current.account.calendar_schedules.order(:id).map { |s| s.as_api_json }
    }
  end

  def save_oauth_credentials
    client_id = params[:client_id].to_s.strip
    client_secret = params[:client_secret].to_s.strip

    custom = (Current.account.custom_attributes || {}).dup
    if client_id.blank? && client_secret.blank?
      custom.delete('google_calendar_oauth')
    else
      existing = (custom['google_calendar_oauth'] || {}).dup
      existing['client_id'] = client_id if client_id.present?
      existing['client_secret'] = client_secret if client_secret.present?
      existing['updated_at'] = Time.current.iso8601
      custom['google_calendar_oauth'] = existing
    end

    Current.account.update!(custom_attributes: custom)

    render json: {
      oauth_configured: Calendar::GoogleCalendarService.oauth_configured?(Current.account),
      has_custom_oauth_credentials: custom.dig('google_calendar_oauth', 'client_id').present?,
      redirect_uri: Calendar::GoogleCalendarService.redirect_uri,
      message: 'Credenciais OAuth 2.0 salvas com sucesso!'
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def auth
    hook_id = params[:hook_id].presence
    schedule_id = params[:schedule_id].presence
    hook = hook_id ? Current.account.hooks.find_by(id: hook_id, app_id: 'google_calendar') : nil

    unless Calendar::GoogleCalendarService.oauth_configured?(Current.account) || (hook&.settings&.dig('oauth_client_id').present? && hook&.settings&.dig('oauth_client_secret').present?)
      return render json: {
        oauth_configured: false,
        redirect_uri: Calendar::GoogleCalendarService.redirect_uri,
        error: 'Configure o OAuth Client ID e Client Secret no painel de credenciais OAuth 2.0 ou use a Conexão Rápida / Token.'
      }, status: :ok
    end

    verifier = Rails.application.message_verifier(:google_calendar_oauth)
    state = verifier.generate(
      {
        account_id: Current.account.id,
        hook_id: hook&.id,
        schedule_id: schedule_id || Array(hook&.settings&.dig('schedule_ids')).first,
        user_id: Current.user.id,
        return_to: params[:return_to].presence || 'integrations',
        exp: 20.minutes.from_now.to_i
      }
    )

    auth_url = Calendar::GoogleCalendarService.authorization_url(
      state: state,
      account: Current.account,
      hook: hook
    )

    render json: {
      oauth_configured: true,
      redirect_url: auth_url,
      authorization_url: auth_url
    }
  end

  def connect
    connection_name = params[:connection_name].to_s.strip
    provider = params[:provider].to_s.strip.presence || 'google_calendar'
    calendar_email = params[:calendar_email].to_s.strip.downcase
    calendar_id = params[:calendar_id].to_s.strip.presence || 'primary'
    access_token = params[:access_token].to_s.strip
    refresh_token = params[:refresh_token].to_s.strip
    oauth_client_id = params[:oauth_client_id].to_s.strip
    oauth_client_secret = params[:oauth_client_secret].to_s.strip
    schedule_ids = Array(params[:schedule_ids]).map(&:to_i).reject(&:zero?).uniq
    agent_ids = Array(params[:agent_ids]).map(&:to_i).reject(&:zero?).uniq

    return render json: { error: 'Informe o nome da conexão ou o e-mail da conta de calendário.' }, status: :unprocessable_entity if connection_name.blank? && calendar_email.blank?

    ref_id = calendar_email.presence || "#{provider}-#{connection_name.parameterize}-#{SecureRandom.hex(3)}"
    hook = Current.account.hooks.find_or_initialize_by(
      app_id: 'google_calendar',
      reference_id: ref_id
    )

    now_iso = Time.current.iso8601
    auth_mode = if access_token.present? || refresh_token.present?
                  'oauth_token'
                elsif oauth_client_id.present?
                  'oauth2_client'
                else
                  'direct_sync'
                end

    hook.access_token = access_token.presence || hook.access_token.presence || "gcal_#{SecureRandom.hex(12)}"
    hook.status = :enabled

    settings_payload = (hook.settings || {}).merge(
      'connection_name' => connection_name.presence || "Agenda • #{calendar_email}",
      'provider' => provider,
      'calendar_email' => calendar_email,
      'calendar_id' => calendar_id,
      'schedule_ids' => schedule_ids,
      'agent_ids' => agent_ids,
      'auth_mode' => auth_mode,
      'last_synced_at' => now_iso,
      'last_tested_at' => now_iso,
      'connection_status' => 'connected'
    )
    settings_payload['oauth_client_id'] = oauth_client_id if oauth_client_id.present?
    settings_payload['oauth_client_secret'] = oauth_client_secret if oauth_client_secret.present?
    if access_token.present? || refresh_token.present?
      settings_payload['oauth_tokens'] = {
        'access_token' => access_token,
        'refresh_token' => refresh_token,
        'email' => calendar_email,
        'expires_at' => 1.hour.from_now.to_i
      }
    end

    hook.settings = settings_payload
    hook.save!

    sync_schedules_from_hook!(hook)

    render json: { hook: serialize_hook(hook) }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_hook
    connection_name = params[:connection_name].to_s.strip
    provider = params[:provider].to_s.strip
    calendar_email = params[:calendar_email].to_s.strip.downcase
    calendar_id = params[:calendar_id].to_s.strip
    access_token = params[:access_token].to_s.strip
    refresh_token = params[:refresh_token].to_s.strip
    oauth_client_id = params[:oauth_client_id].to_s.strip
    oauth_client_secret = params[:oauth_client_secret].to_s.strip
    schedule_ids = Array(params[:schedule_ids]).map(&:to_i).reject(&:zero?).uniq
    agent_ids = Array(params[:agent_ids]).map(&:to_i).reject(&:zero?).uniq

    updated = (@hook.settings || {}).dup
    updated['connection_name'] = connection_name if connection_name.present?
    updated['provider'] = provider if provider.present?
    updated['calendar_email'] = calendar_email if calendar_email.present?
    updated['calendar_id'] = calendar_id if calendar_id.present?
    updated['schedule_ids'] = schedule_ids if params.key?(:schedule_ids)
    updated['agent_ids'] = agent_ids if params.key?(:agent_ids)
    updated['oauth_client_id'] = oauth_client_id if oauth_client_id.present?
    updated['oauth_client_secret'] = oauth_client_secret if oauth_client_secret.present?

    if access_token.present?
      @hook.access_token = access_token
      updated['auth_mode'] = 'oauth_token'
      updated['oauth_tokens'] = (updated['oauth_tokens'] || {}).merge(
        'access_token' => access_token,
        'refresh_token' => refresh_token.presence || updated.dig('oauth_tokens', 'refresh_token')
      )
    end

    updated['last_tested_at'] = Time.current.iso8601
    updated['connection_status'] = 'connected'
    @hook.settings = updated
    @hook.save!

    sync_schedules_from_hook!(@hook)

    render json: { hook: serialize_hook(@hook) }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def test_connection
    now_iso = Time.current.iso8601
    schedule_ids = Array(@hook.settings&.dig('schedule_ids')).map(&:to_i).reject(&:zero?)
    linked_schedules = Current.account.calendar_schedules.where(id: schedule_ids)

    busy_checked = 0
    linked_schedules.each do |sched|
      intervals = Calendar::GoogleCalendarService.new(sched).busy_intervals(Time.current, 7.days.from_now)
      busy_checked += intervals.size
    end

    @hook.settings = (@hook.settings || {}).merge(
      'last_tested_at' => now_iso,
      'connection_status' => 'connected'
    )
    @hook.save!

    render json: {
      hook: serialize_hook(@hook),
      status: 'connected',
      busy_intervals_checked: busy_checked,
      message: "Conexão verificada com sucesso (#{linked_schedules.count} agenda(s) vinculada(s))."
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_events
    now_iso = Time.current.iso8601
    sync_schedules_from_hook!(@hook)
    schedule_ids = Array(@hook.settings&.dig('schedule_ids')).map(&:to_i).reject(&:zero?)
    appts_count = Current.account.calendar_appointments.where(calendar_schedule_id: schedule_ids, status: %w[confirmed pending]).count

    @hook.settings = (@hook.settings || {}).merge(
      'last_synced_at' => now_iso,
      'last_tested_at' => now_iso,
      'connection_status' => 'connected',
      'synced_events_count' => appts_count
    )
    @hook.save!

    render json: {
      hook: serialize_hook(@hook),
      synced_events_count: appts_count,
      message: "Sincronização concluída! #{appts_count} compromisso(s) ativo(s) sincronizado(s)."
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    schedule_ids = Array(@hook.settings&.dig('schedule_ids')).map(&:to_i).reject(&:zero?)
    @hook.destroy!

    # If no other active hook references a schedule, mark it disconnected only if requested
    if params[:disconnect_schedules].present?
      Current.account.calendar_schedules.where(id: schedule_ids).update_all(google_connected: false)
    end

    head :no_content
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.where(app_id: 'google_calendar').find(params[:hook_id] || params[:id])
  end

  def ensure_hooks_bootstrapped_from_schedules!
    Current.account.calendar_schedules.where(google_connected: true).find_each do |sched|
      email_ref = sched.google_email.presence || "schedule-#{sched.id}@meusuper.app"
      hook = Current.account.hooks.find_or_initialize_by(
        app_id: 'google_calendar',
        reference_id: email_ref
      )
      next unless hook.new_record?

      now_iso = Time.current.iso8601
      hook.access_token = sched.google_credentials&.dig('access_token').presence || "gcal_#{SecureRandom.hex(10)}"
      hook.status = :enabled
      hook.settings = {
        'connection_name' => "Agenda • #{sched.name}",
        'provider' => 'google_calendar',
        'calendar_email' => email_ref,
        'calendar_id' => sched.google_calendar_id.presence || 'primary',
        'schedule_ids' => [sched.id],
        'agent_ids' => [sched.user_id].compact,
        'auth_mode' => sched.google_credentials&.dig('access_token').present? ? 'oauth2' : 'direct_sync',
        'connection_status' => 'connected',
        'last_synced_at' => now_iso,
        'last_tested_at' => now_iso
      }
      hook.save!
    end
  end

  def sync_schedules_from_hook!(hook)
    schedule_ids = Array(hook.settings&.dig('schedule_ids')).map(&:to_i).reject(&:zero?)
    return if schedule_ids.empty?

    creds = hook.settings&.dig('oauth_tokens') || {}
    Current.account.calendar_schedules.where(id: schedule_ids).find_each do |sched|
      sched.update!(
        google_connected: true,
        google_email: hook.settings['calendar_email'].presence || sched.google_email,
        google_calendar_id: hook.settings['calendar_id'].presence || sched.google_calendar_id.presence || 'primary',
        google_credentials: (sched.google_credentials || {}).merge(creds)
      )
    end
  end

  def serialize_hook(hook)
    sids = Array(hook.settings&.dig('schedule_ids')).map(&:to_i).reject(&:zero?)
    linked_names = Current.account.calendar_schedules.where(id: sids).pluck(:name)
    {
      id: hook.id,
      app_id: hook.app_id,
      status: hook.status,
      reference_id: hook.reference_id,
      settings: (hook.settings || {}).merge(
        'linked_schedule_names' => linked_names,
        'oauth_client_id_configured' => hook.settings&.dig('oauth_client_id').present? || Calendar::GoogleCalendarService.oauth_configured?(Current.account)
      )
    }
  end
end

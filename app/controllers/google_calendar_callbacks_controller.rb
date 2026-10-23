# frozen_string_literal: true

class GoogleCalendarCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def show
    if params[:error].present?
      return redirect_to "/app?google_calendar_error=#{CGI.escape(params[:error].to_s)}"
    end

    verifier = Rails.application.message_verifier(:google_calendar_oauth)
    payload = verifier.verify(params[:state].to_s)
    raise 'Token de autorização expirado' if payload['exp'].to_i < Time.current.to_i

    account = Account.find(payload['account_id'])
    hook = payload['hook_id'].present? ? account.hooks.find_by(id: payload['hook_id'], app_id: 'google_calendar') : nil
    schedule = payload['schedule_id'].present? ? account.calendar_schedules.find_by(id: payload['schedule_id']) : nil

    creds = Calendar::GoogleCalendarService.exchange_code!(params[:code].to_s, account: account, hook: hook)
    now_iso = Time.current.iso8601

    if hook.present?
      hook_settings = (hook.settings || {}).merge(
        'calendar_email' => creds['email'].presence || hook.settings&.dig('calendar_email'),
        'auth_mode' => 'oauth2',
        'connection_status' => 'connected',
        'last_synced_at' => now_iso,
        'last_tested_at' => now_iso,
        'oauth_tokens' => creds
      )
      hook.access_token = creds['access_token'] if creds['access_token'].present?
      hook.status = :enabled
      hook.settings = hook_settings
      hook.save!

      schedule_ids = Array(hook.settings['schedule_ids']).map(&:to_i).reject(&:zero?)
      account.calendar_schedules.where(id: schedule_ids).find_each do |s|
        s.update!(
          google_connected: true,
          google_email: creds['email'].presence || s.google_email,
          google_calendar_id: hook.settings['calendar_id'].presence || s.google_calendar_id.presence || 'primary',
          google_credentials: (s.google_credentials || {}).merge(creds)
        )
      end
    end

    if schedule.present?
      schedule.update!(
        google_connected: true,
        google_email: creds['email'].presence || schedule.google_email,
        google_calendar_id: schedule.google_calendar_id.presence || 'primary',
        google_credentials: (schedule.google_credentials || {}).merge(creds)
      )

      # Also mirror into Integrations::Hook so Settings -> Integrations lists it
      mirrored_hook = account.hooks.find_or_initialize_by(
        app_id: 'google_calendar',
        reference_id: creds['email'].presence || "schedule-#{schedule.id}"
      )
      mirrored_hook.access_token = creds['access_token'] if creds['access_token'].present?
      mirrored_hook.status = :enabled
      existing_sids = Array(mirrored_hook.settings&.dig('schedule_ids')).map(&:to_i)
      mirrored_hook.settings = (mirrored_hook.settings || {}).merge(
        'connection_name' => mirrored_hook.settings&.dig('connection_name').presence || "Agenda • #{schedule.name}",
        'provider' => 'google_calendar',
        'calendar_email' => creds['email'].presence || schedule.google_email,
        'calendar_id' => schedule.google_calendar_id.presence || 'primary',
        'schedule_ids' => (existing_sids + [schedule.id]).uniq,
        'auth_mode' => 'oauth2',
        'connection_status' => 'connected',
        'last_synced_at' => now_iso,
        'last_tested_at' => now_iso,
        'oauth_tokens' => creds
      )
      mirrored_hook.save!
    end

    return_to = payload['return_to'].to_s
    if return_to == 'integrations'
      redirect_to "/app/accounts/#{account.id}/settings/integrations/google_calendar?google_connected=1"
    else
      redirect_to "/app/accounts/#{account.id}/agendamentos?google_connected=1&schedule_id=#{schedule&.id}"
    end
  rescue StandardError => e
    Rails.logger.error("[GoogleCalendarCallbacksController] OAuth error: #{e.message}")
    acc_id = payload.is_a?(Hash) ? payload['account_id'] : nil
    if acc_id && payload['return_to'] == 'integrations'
      redirect_to "/app/accounts/#{acc_id}/settings/integrations/google_calendar?error=#{CGI.escape(e.message.to_s.truncate(120))}"
    else
      redirect_to "/app?google_calendar_error=#{CGI.escape(e.message.to_s.truncate(120))}"
    end
  end
end

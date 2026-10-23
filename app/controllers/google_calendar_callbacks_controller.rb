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
    schedule = account.calendar_schedules.find(payload['schedule_id'])

    creds = Calendar::GoogleCalendarService.exchange_code!(params[:code].to_s)
    schedule.update!(
      google_connected: true,
      google_email: creds['email'].presence || schedule.google_email,
      google_calendar_id: schedule.google_calendar_id.presence || 'primary',
      google_credentials: (schedule.google_credentials || {}).merge(creds)
    )

    redirect_to "/app/accounts/#{account.id}/agendamentos?google_connected=1&schedule_id=#{schedule.id}"
  rescue StandardError => e
    Rails.logger.error("[GoogleCalendarCallbacksController] OAuth error: #{e.message}")
    redirect_to "/app?google_calendar_error=#{CGI.escape(e.message.to_s.truncate(120))}"
  end
end

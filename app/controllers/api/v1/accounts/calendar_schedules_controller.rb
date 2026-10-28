# frozen_string_literal: true

class Api::V1::Accounts::CalendarSchedulesController < Api::V1::Accounts::BaseController
  before_action :fetch_schedule, only: [:show, :update, :destroy, :google_auth_url, :disconnect_google]

  def index
    schedules = Current.account.calendar_schedules.includes(:appointment_types, :user).order(:id)
    types = Current.account.appointment_types.order(:id)

    today_start = Time.current.beginning_of_day
    today_end = Time.current.end_of_day
    counts_by_schedule = Current.account.calendar_appointments
                                .where(status: %w[confirmed pending], starts_at: today_start..today_end)
                                .group(:calendar_schedule_id)
                                .count

    team_slug = schedules.first&.team_booking_slug || Current.account.name.to_s.parameterize.presence || "conta-#{Current.account.id}"
    base_url = ENV.fetch('AGENDA_URL', 'https://agenda.meusuper.app').sub(%r{/+$}, '')

    render json: {
      schedules: schedules.map { |s| s.as_api_json(today_count: counts_by_schedule[s.id] || 0) },
      appointment_types: types.map(&:as_api_json),
      google_oauth_configured: Calendar::GoogleCalendarService.oauth_configured?(Current.account),
      google_oauth_redirect_uri: Calendar::GoogleCalendarService.redirect_uri,
      integration_hooks_count: Current.account.hooks.where(app_id: 'google_calendar', status: :enabled).count,
      team_public_url: "#{base_url}/#{team_slug}"
    }
  end

  def show
    render json: @schedule.as_api_json
  end

  def create
    schedule = Current.account.calendar_schedules.new(schedule_params)
    schedule.user ||= Current.user
    schedule.save!
    ensure_default_appointment_types(schedule)
    render json: schedule.reload.as_api_json, status: :created
  end

  def update
    @schedule.update!(schedule_params)
    render json: @schedule.reload.as_api_json
  end

  def destroy
    @schedule.destroy!
    head :no_content
  end

  def google_auth_url
    unless Calendar::GoogleCalendarService.oauth_configured?(Current.account)
      return render json: {
        oauth_configured: false,
        redirect_uri: Calendar::GoogleCalendarService.redirect_uri,
        integrations_path: "/app/accounts/#{Current.account.id}/settings/integrations/google_calendar",
        message: 'Configure as credenciais OAuth 2.0 em Configurações → Integrações → Agendamento Inteligente IA ou conecte direto pela central de integrações.'
      }, status: :ok
    end

    verifier = Rails.application.message_verifier(:google_calendar_oauth)
    state = verifier.generate(
      {
        account_id: Current.account.id,
        schedule_id: @schedule.id,
        user_id: Current.user.id,
        return_to: params[:return_to].presence || 'calendar',
        exp: 20.minutes.from_now.to_i
      }
    )
    render json: {
      oauth_configured: true,
      authorization_url: Calendar::GoogleCalendarService.authorization_url(state: state, account: Current.account)
    }
  end

  def disconnect_google
    @schedule.update!(
      google_connected: false,
      google_credentials: {},
      google_email: nil
    )
    render json: @schedule.as_api_json
  end

  def upsert_appointment_type
    type = if params[:id].present?
             Current.account.appointment_types.find(params[:id])
           else
             Current.account.appointment_types.new
           end
    type.assign_attributes(appointment_type_params)
    type.save!
    render json: type.as_api_json
  end

  def destroy_appointment_type
    type = Current.account.appointment_types.find(params[:type_id])
    type.destroy!
    head :no_content
  end

  private

  def fetch_schedule
    @schedule = Current.account.calendar_schedules.find(params[:id])
  end

  def schedule_params
    permitted = params.require(:calendar_schedule).permit(
      :name,
      :slug,
      :user_id,
      :role_title,
      :bio,
      :avatar_url,
      :color,
      :timezone,
      :active,
      :ai_bookable,
      :google_email,
      :google_calendar_id,
      :google_connected,
      :slot_duration_minutes,
      :buffer_before_minutes,
      :buffer_after_minutes,
      :minimum_notice_minutes,
      :max_days_ahead,
      weekly_hours: {},
      settings: {}
    )
    if params[:calendar_schedule][:weekly_hours].present?
      permitted[:weekly_hours] = params[:calendar_schedule][:weekly_hours].to_unsafe_h
    end
    if params[:calendar_schedule][:settings].present?
      permitted[:settings] = params[:calendar_schedule][:settings].to_unsafe_h
    end
    permitted
  end

  def appointment_type_params
    params.require(:appointment_type).permit(
      :calendar_schedule_id,
      :title,
      :slug,
      :description,
      :duration_minutes,
      :buffer_minutes,
      :location_type,
      :location_details,
      :color,
      :active,
      :price_cents,
      :currency,
      custom_questions: [:label, :name, :required, :type]
    )
  end

  def ensure_default_appointment_types(schedule)
    return if schedule.appointment_types.exists?

    schedule.appointment_types.create!(
      account: Current.account,
      title: 'Sessão Estratégica & Demo (30 min)',
      duration_minutes: schedule.slot_duration_minutes || 30,
      buffer_minutes: schedule.buffer_after_minutes || 15,
      location_type: 'google_meet',
      color: schedule.color,
      description: "Reunião executiva online com #{schedule.name} pela Sala de Vídeo Meu Super Chat."
    )
  end
end

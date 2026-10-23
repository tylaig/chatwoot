# frozen_string_literal: true

class Api::V1::Accounts::CalendarAppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_appointment, only: [:show, :update, :destroy, :cancel, :reschedule]

  def index
    scope = Current.account.calendar_appointments.includes(:calendar_schedule, :appointment_type, :contact, :conversation)

    if params[:calendar_schedule_id].present? && params[:calendar_schedule_id].to_s != 'all'
      scope = scope.where(calendar_schedule_id: params[:calendar_schedule_id])
    end
    scope = scope.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    scope = scope.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    scope = scope.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'
    scope = scope.where(source: params[:source]) if params[:source].present? && params[:source] != 'all'

    if params[:start_date].present? && params[:end_date].present?
      from_time = Time.zone.parse(params[:start_date].to_s)&.beginning_of_day
      to_time = Time.zone.parse(params[:end_date].to_s)&.end_of_day
      scope = scope.where('starts_at <= ? AND ends_at >= ?', to_time, from_time) if from_time && to_time
    end

    if params[:q].present?
      q = "%#{params[:q].to_s.strip}%"
      scope = scope.where('title ILIKE :q OR customer_name ILIKE :q OR customer_email ILIKE :q OR customer_phone ILIKE :q', q: q)
    end

    appointments = scope.order(starts_at: :asc).limit(500)

    all_account_scope = Current.account.calendar_appointments
    today_range = Time.current.beginning_of_day..Time.current.end_of_day
    total_finished = all_account_scope.where(status: %w[completed no_show]).count
    no_shows = all_account_scope.where(status: 'no_show').count
    no_show_rate = total_finished.positive? ? ((no_shows.to_f / total_finished) * 100.0).round(1) : 0.0

    stats = {
      total: appointments.size,
      today_confirmed: all_account_scope.where(status: 'confirmed', starts_at: today_range).count,
      pending: all_account_scope.where(status: 'pending').where('starts_at >= ?', Time.current).count,
      ai_booked: all_account_scope.where(source: 'ai_agent').where.not(status: 'cancelled').count,
      public_booked: all_account_scope.where(source: 'public_link').where.not(status: 'cancelled').count,
      no_show_rate: no_show_rate
    }

    render json: {
      appointments: appointments.map(&:as_api_json),
      stats: stats
    }
  end

  def availability
    schedules = if params[:calendar_schedule_id].present? && params[:calendar_schedule_id].to_s != 'all'
                  Current.account.calendar_schedules.active.where(id: params[:calendar_schedule_id])
                else
                  Current.account.calendar_schedules.active.order(:id)
                end

    appointment_type = params[:appointment_type_id].present? ? Current.account.appointment_types.find_by(id: params[:appointment_type_id]) : nil

    slots = Calendar::AvailabilityService.new(
      account: Current.account,
      schedules: schedules,
      appointment_type: appointment_type
    ).available_slots(
      date_str: params[:date],
      days: (params[:days] || 7).to_i
    )

    render json: { availability: slots }
  end

  def show
    render json: @appointment.as_api_json
  end

  def create
    booking = Calendar::BookingService.new(account: Current.account).create!(
      appointment_params.to_h.symbolize_keys.merge(source: params.dig(:calendar_appointment, :source).presence || 'operator')
    )
    render json: booking.as_api_json, status: :created
  rescue Calendar::BookingService::SlotUnavailableError => e
    render json: { error: e.message }, status: :conflict
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    if params.dig(:calendar_appointment, :starts_at).present? &&
       Time.zone.parse(params.dig(:calendar_appointment, :starts_at).to_s) != @appointment.starts_at
      updated = Calendar::BookingService.new(account: Current.account).reschedule!(
        appointment: @appointment,
        new_starts_at: params.dig(:calendar_appointment, :starts_at),
        new_ends_at: params.dig(:calendar_appointment, :ends_at),
        notes: params.dig(:calendar_appointment, :notes)
      )
      return render json: updated.as_api_json
    end

    @appointment.update!(appointment_update_params)
    Calendar::GoogleCalendarService.new(@appointment.calendar_schedule).update_event(@appointment)
    render json: @appointment.reload.as_api_json
  rescue Calendar::BookingService::SlotUnavailableError => e
    render json: { error: e.message }, status: :conflict
  end

  def reschedule
    updated = Calendar::BookingService.new(account: Current.account).reschedule!(
      appointment: @appointment,
      new_starts_at: params[:starts_at],
      new_ends_at: params[:ends_at],
      notes: params[:notes]
    )
    render json: updated.as_api_json
  rescue Calendar::BookingService::SlotUnavailableError => e
    render json: { error: e.message }, status: :conflict
  end

  def cancel
    cancelled = Calendar::BookingService.new(account: Current.account).cancel!(
      appointment: @appointment,
      reason: params[:reason]
    )
    render json: cancelled.as_api_json
  end

  def destroy
    Calendar::GoogleCalendarService.new(@appointment.calendar_schedule).update_event(
      @appointment.tap { |a| a.status = 'cancelled' }
    )
    @appointment.destroy!
    head :no_content
  end

  private

  def fetch_appointment
    @appointment = Current.account.calendar_appointments.find(params[:id])
  end

  def appointment_params
    params.require(:calendar_appointment).permit(
      :calendar_schedule_id,
      :professional_slug,
      :appointment_type_id,
      :contact_id,
      :conversation_id,
      :title,
      :notes,
      :customer_name,
      :customer_email,
      :customer_phone,
      :starts_at,
      :ends_at,
      :duration_minutes,
      :status,
      :source,
      :location_type,
      metadata: {}
    )
  end

  def appointment_update_params
    params.require(:calendar_appointment).permit(
      :title,
      :notes,
      :customer_name,
      :customer_email,
      :customer_phone,
      :status,
      :location_type,
      :meeting_url
    )
  end
end

# frozen_string_literal: true

class PublicBookingsController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false

  # GET /agendar/:slug
  def show
    @slug = params[:slug].to_s.parameterize
    @global_config = GlobalConfig.get('BRAND_NAME', 'INSTALLATION_NAME', 'LOGO_THUMBNAIL', 'BRAND_COLOR')
    render template: 'public_bookings/show', layout: false
  end

  # GET /agendar/sala/:uid or /reuniao/:uid
  def show_meeting
    @appointment = CalendarAppointment.includes(:calendar_schedule).find_by(uid: params[:uid].to_s.strip)
    @global_config = GlobalConfig.get('BRAND_NAME', 'INSTALLATION_NAME', 'LOGO_THUMBNAIL', 'BRAND_COLOR')
    render template: 'public_bookings/show_meeting', layout: false
  end

  # GET /public/api/v1/bookings/:slug
  def profile
    target = resolve_booking_target!(params[:slug])

    if target[:mode] == :professional
      schedule = target[:schedule]
      account = schedule.account
      types = schedule.appointment_types.active.order(:id)
      types = account.appointment_types.active.where(calendar_schedule_id: nil).order(:id) if types.empty?

      render json: {
        mode: 'professional',
        account_name: account.name,
        team_slug: schedule.team_booking_slug,
        schedule: public_schedule_json(schedule),
        schedules: [public_schedule_json(schedule)],
        appointment_types: types.map(&:as_api_json)
      }
    else
      account = target[:account]
      schedules = target[:schedules]
      types = account.appointment_types.active.order(:id)

      render json: {
        mode: 'team',
        account_name: account.name,
        team_slug: params[:slug],
        schedule: nil,
        schedules: schedules.map { |s| public_schedule_json(s) },
        appointment_types: types.map(&:as_api_json)
      }
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # GET /public/api/v1/bookings/:slug/slots?date=YYYY-MM-DD&days=7&schedule_id=...&appointment_type_id=...
  def slots
    target = resolve_booking_target!(params[:slug])
    account = target[:account]
    schedules = if params[:schedule_id].present?
                  account.calendar_schedules.active.where(id: params[:schedule_id])
                elsif target[:mode] == :professional
                  [target[:schedule]]
                else
                  target[:schedules]
                end

    appointment_type = params[:appointment_type_id].present? ? account.appointment_types.active.find_by(id: params[:appointment_type_id]) : nil

    availability = Calendar::AvailabilityService.new(
      account: account,
      schedules: schedules,
      appointment_type: appointment_type
    ).available_slots(
      date_str: params[:date],
      days: (params[:days] || 7).to_i
    )

    render json: { availability: availability }
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  # POST /public/api/v1/bookings/:slug/book
  def book
    target = resolve_booking_target!(params[:slug])
    account = target[:account]
    schedule_id = params[:calendar_schedule_id].presence || target[:schedule]&.id

    guest_emails = Array(params[:guest_emails]).map { |e| e.to_s.strip }.reject(&:blank?)

    appointment = Calendar::BookingService.new(account: account).create!(
      calendar_schedule_id: schedule_id,
      appointment_type_id: params[:appointment_type_id],
      starts_at: params[:starts_at],
      customer_name: params[:customer_name],
      customer_email: params[:customer_email],
      customer_phone: params[:customer_phone],
      notes: params[:notes],
      source: 'public_link',
      metadata: {
        booked_via_slug: params[:slug],
        guest_emails: guest_emails.presence
      }.compact
    )

    render json: {
      message: 'Agendamento confirmado com sucesso!',
      appointment: appointment.as_api_json
    }, status: :created
  rescue Calendar::BookingService::SlotUnavailableError => e
    render json: { error: e.message }, status: :conflict
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def resolve_booking_target!(raw_slug)
    slug = raw_slug.to_s.parameterize
    schedule = CalendarSchedule.active.includes(:account, :appointment_types).find_by(slug: slug)
    return { mode: :professional, schedule: schedule, account: schedule.account } if schedule.present?

    # Check team/account slug
    by_team_setting = CalendarSchedule.active.includes(:account).where("settings ->> 'team_slug' = ?", slug)
    if by_team_setting.exists?
      acc = by_team_setting.first.account
      return { mode: :team, account: acc, schedules: acc.calendar_schedules.active.order(:id) }
    end

    matched_account = Account.all.find { |a| a.name.to_s.parameterize == slug || "conta-#{a.id}" == slug }
    if matched_account && matched_account.calendar_schedules.active.exists?
      return { mode: :team, account: matched_account, schedules: matched_account.calendar_schedules.active.order(:id) }
    end

    raise ActiveRecord::RecordNotFound, 'Página de agendamento não encontrada.'
  end

  def public_schedule_json(schedule)
    {
      id: schedule.id,
      name: schedule.name,
      slug: schedule.slug,
      role_title: schedule.role_title,
      bio: schedule.bio,
      avatar_url: schedule.avatar_url.presence || schedule.user&.avatar_url,
      color: schedule.color,
      timezone: schedule.timezone,
      slot_duration_minutes: schedule.slot_duration_minutes,
      google_connected: schedule.google_connected,
      public_booking_url: schedule.public_booking_url,
      appointment_types: schedule.appointment_types.active.order(:id).map(&:as_api_json)
    }
  end
end

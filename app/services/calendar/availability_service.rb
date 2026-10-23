# frozen_string_literal: true

class Calendar::AvailabilityService
  PT_WEEKDAYS = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado].freeze

  def initialize(account:, schedules: nil, appointment_type: nil)
    @account = account
    @appointment_type = appointment_type
    @schedules = schedules || resolve_default_schedules
  end

  # Returns available slots for a single date (YYYY-MM-DD) or range of dates across one or multiple professionals
  def available_slots(date_str:, days: 1)
    start_date = parse_date(date_str) || Time.current.in_time_zone(primary_timezone).to_date
    days_count = days.to_i.clamp(1, 14)
    results = []

    @schedules.each do |schedule|
      tz = ActiveSupport::TimeZone[schedule.timezone] || ActiveSupport::TimeZone['America/Sao_Paulo']
      duration = (@appointment_type&.duration_minutes || schedule.slot_duration_minutes || 30).to_i
      buffer_before = schedule.buffer_before_minutes.to_i
      buffer_after = (@appointment_type&.buffer_minutes || schedule.buffer_after_minutes || 15).to_i

      range_start = tz.local(start_date.year, start_date.month, start_date.day, 0, 0, 0)
      end_date = start_date + (days_count - 1).days
      range_end = tz.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)

      busy_ranges = collect_busy_ranges(schedule, range_start, range_end, buffer_before, buffer_after)
      earliest_allowed = Time.current + schedule.minimum_notice_minutes.minutes
      latest_allowed = Time.current + schedule.max_days_ahead.days

      (0...days_count).each do |offset|
        day = start_date + offset.days
        wday_key = day.wday.to_s
        intervals = Array(schedule.effective_weekly_hours[wday_key])
        next if intervals.empty?

        day_slots = []
        intervals.each do |interval|
          sh, sm = interval['start'].to_s.split(':').map(&:to_i)
          eh, em = interval['end'].to_s.split(':').map(&:to_i)
          window_start = tz.local(day.year, day.month, day.day, sh, sm, 0)
          window_end = tz.local(day.year, day.month, day.day, eh, em, 0)

          cursor = window_start
          step_minutes = [duration, 30].min
          step_minutes = 15 if step_minutes < 15

          while (cursor + duration.minutes) <= window_end
            slot_end = cursor + duration.minutes
            if cursor >= earliest_allowed && cursor <= latest_allowed && !overlaps_busy?(cursor, slot_end, busy_ranges)
              day_slots << {
                starts_at: cursor.iso8601,
                ends_at: slot_end.iso8601,
                date: day.strftime('%Y-%m-%d'),
                weekday: PT_WEEKDAYS[day.wday],
                time: cursor.strftime('%H:%M'),
                end_time: slot_end.strftime('%H:%M'),
                duration_minutes: duration,
                calendar_schedule_id: schedule.id,
                professional_name: schedule.name,
                professional_slug: schedule.slug,
                professional_role: schedule.role_title,
                timezone: schedule.timezone
              }
            end
            cursor += step_minutes.minutes
          end
        end

        next if day_slots.empty?

        results << {
          date: day.strftime('%Y-%m-%d'),
          weekday: PT_WEEKDAYS[day.wday],
          calendar_schedule_id: schedule.id,
          professional_name: schedule.name,
          professional_slug: schedule.slug,
          professional_role: schedule.role_title,
          public_booking_url: schedule.public_booking_url,
          slots: day_slots
        }
      end
    end

    results
  end

  def slot_available?(schedule:, starts_at:, ends_at:, exclude_appointment_id: nil)
    tz = ActiveSupport::TimeZone[schedule.timezone] || ActiveSupport::TimeZone['America/Sao_Paulo']
    local_start = starts_at.in_time_zone(tz)
    local_end = ends_at.in_time_zone(tz)

    scope = schedule.calendar_appointments.active_bookings
    scope = scope.where.not(id: exclude_appointment_id) if exclude_appointment_id.present?

    buffer_before = schedule.buffer_before_minutes.to_i.minutes
    buffer_after = schedule.buffer_after_minutes.to_i.minutes

    db_conflict = scope.exists?(
      ['starts_at < ? AND ends_at > ?', local_end + buffer_after, local_start - buffer_before]
    )
    return false if db_conflict

    google_busy = Calendar::GoogleCalendarService.new(schedule).busy_intervals(
      local_start - buffer_before,
      local_end + buffer_after
    )
    google_busy.none? { |b_start, b_end| local_start < b_end && local_end > b_start }
  end

  private

  def resolve_default_schedules
    if @appointment_type&.calendar_schedule.present?
      [@appointment_type.calendar_schedule]
    else
      @account.calendar_schedules.active.order(:id).to_a
    end
  end

  def primary_timezone
    @schedules.first&.timezone || 'America/Sao_Paulo'
  end

  def parse_date(date_str)
    return nil if date_str.blank?

    Date.parse(date_str.to_s)
  rescue ArgumentError
    nil
  end

  def collect_busy_ranges(schedule, range_start, range_end, buffer_before, buffer_after)
    ranges = schedule.calendar_appointments
                     .active_bookings
                     .where('starts_at < ? AND ends_at > ?', range_end, range_start)
                     .pluck(:starts_at, :ends_at)
                     .map { |s, e| [s - buffer_before.minutes, e + buffer_after.minutes] }

    google_ranges = Calendar::GoogleCalendarService.new(schedule).busy_intervals(range_start, range_end)
    google_ranges.each do |gs, ge|
      ranges << [gs - buffer_before.minutes, ge + buffer_after.minutes]
    end

    ranges
  end

  def overlaps_busy?(slot_start, slot_end, busy_ranges)
    busy_ranges.any? { |b_start, b_end| slot_start < b_end && slot_end > b_start }
  end
end

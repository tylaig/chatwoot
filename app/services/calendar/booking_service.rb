# frozen_string_literal: true

class Calendar::BookingService
  class SlotUnavailableError < StandardError; end

  def initialize(account:)
    @account = account
  end

  def create!(params = {})
    p = params.to_h.symbolize_keys
    schedule = resolve_schedule!(p)
    appointment_type = resolve_appointment_type(schedule, p[:appointment_type_id])

    tz = ActiveSupport::TimeZone[schedule.timezone] || ActiveSupport::TimeZone['America/Sao_Paulo']
    starts_at = parse_in_zone(p[:starts_at], tz)
    raise ArgumentError, 'Data e horário de início inválidos.' unless starts_at

    duration_minutes = (
      p[:duration_minutes].presence ||
      appointment_type&.duration_minutes ||
      schedule.slot_duration_minutes ||
      30
    ).to_i

    ends_at = if p[:ends_at].present?
                parse_in_zone(p[:ends_at], tz)
              else
                starts_at + duration_minutes.minutes
              end

    availability = Calendar::AvailabilityService.new(
      account: @account,
      schedules: [schedule],
      appointment_type: appointment_type
    )

    unless availability.slot_available?(schedule: schedule, starts_at: starts_at, ends_at: ends_at)
      raise SlotUnavailableError, "O horário #{starts_at.strftime('%d/%m/%Y às %H:%M')} não está disponível para #{schedule.name}."
    end

    contact = resolve_or_create_contact(
      contact_id: p[:contact_id],
      name: p[:customer_name],
      email: p[:customer_email],
      phone: p[:customer_phone]
    )

    title = p[:title].presence ||
            appointment_type&.title.presence ||
            "Atendimento — #{p[:customer_name].presence || contact&.name || 'Cliente'}"

    location_type = p[:location_type].presence || appointment_type&.location_type || 'google_meet'

    appointment = @account.calendar_appointments.new(
      calendar_schedule: schedule,
      appointment_type: appointment_type,
      contact_id: contact&.id,
      conversation_id: p[:conversation_id],
      title: title,
      notes: p[:notes],
      customer_name: p[:customer_name].presence || contact&.name.presence || 'Cliente',
      customer_email: p[:customer_email].presence || contact&.email,
      customer_phone: p[:customer_phone].presence || contact&.phone_number,
      starts_at: starts_at,
      ends_at: ends_at,
      timezone: schedule.timezone,
      status: p[:status].presence || 'confirmed',
      source: p[:source].presence || 'operator',
      location_type: location_type,
      meeting_url: p[:meeting_url],
      metadata: p[:metadata].is_a?(Hash) ? p[:metadata] : {}
    )

    appointment.save!

    # Sync with Google Calendar (or generate instant Meu Super Chat Meet room link)
    gcal_result = Calendar::GoogleCalendarService.new(schedule).create_event(appointment)
    if gcal_result.is_a?(Hash)
      updates = {}
      updates[:google_event_id] = gcal_result[:google_event_id] if gcal_result[:google_event_id].present?
      updates[:google_calendar_id] = gcal_result[:google_calendar_id] if gcal_result[:google_calendar_id].present?
      if appointment.meeting_url.blank? && gcal_result[:meeting_url].present?
        updates[:meeting_url] = gcal_result[:meeting_url]
      end
      appointment.update_columns(updates) if updates.any?
    end

    if appointment.meeting_url.blank? && location_type == 'google_meet'
      base_url = ENV.fetch('MEET_URL', 'https://meet.meusuper.app').sub(%r{/+$}, '')
      appointment.update_columns(meeting_url: "#{base_url}/#{appointment.uid}")
    end

    appointment.reload
  end

  def reschedule!(appointment:, new_starts_at:, new_ends_at: nil, notes: nil)
    schedule = appointment.calendar_schedule
    tz = ActiveSupport::TimeZone[schedule.timezone] || ActiveSupport::TimeZone['America/Sao_Paulo']
    starts_at = parse_in_zone(new_starts_at, tz)
    raise ArgumentError, 'Nova data/hora inválida.' unless starts_at

    duration_minutes = appointment.duration_minutes.positive? ? appointment.duration_minutes : schedule.slot_duration_minutes
    ends_at = new_ends_at.present? ? parse_in_zone(new_ends_at, tz) : (starts_at + duration_minutes.minutes)

    availability = Calendar::AvailabilityService.new(account: @account, schedules: [schedule])
    unless availability.slot_available?(
      schedule: schedule,
      starts_at: starts_at,
      ends_at: ends_at,
      exclude_appointment_id: appointment.id
    )
      raise SlotUnavailableError, "O novo horário #{starts_at.strftime('%d/%m/%Y às %H:%M')} já está ocupado para #{schedule.name}."
    end

    merged_notes = notes.present? ? [appointment.notes, "Reagendado: #{notes}"].compact.join("\n") : appointment.notes
    appointment.update!(
      starts_at: starts_at,
      ends_at: ends_at,
      notes: merged_notes,
      status: 'confirmed'
    )

    Calendar::GoogleCalendarService.new(schedule).update_event(appointment)
    appointment.reload
  end

  def cancel!(appointment:, reason: nil)
    merged_notes = reason.present? ? [appointment.notes, "Cancelado: #{reason}"].compact.join("\n") : appointment.notes
    appointment.update!(
      status: 'cancelled',
      notes: merged_notes
    )
    Calendar::GoogleCalendarService.new(appointment.calendar_schedule).cancel_event(appointment)
    appointment.reload
  end

  private

  def resolve_schedule!(p)
    if p[:calendar_schedule_id].present? && p[:calendar_schedule_id].to_s != 'all'
      sched = @account.calendar_schedules.active.find_by(id: p[:calendar_schedule_id])
      return sched if sched
    end

    if p[:professional_slug].present?
      q = p[:professional_slug].to_s.strip
      sched = @account.calendar_schedules.active.find_by(slug: q.parameterize) ||
              @account.calendar_schedules.active.where('LOWER(name) LIKE ?', "%#{q.downcase}%").first
      return sched if sched
    end

    sched = @account.calendar_schedules.active.order(:id).first
    raise ActiveRecord::RecordNotFound, 'Nenhum profissional com agenda ativa encontrado.' unless sched

    sched
  end

  def resolve_appointment_type(schedule, appointment_type_id)
    return nil if appointment_type_id.blank?

    @account.appointment_types.active.find_by(id: appointment_type_id) ||
      schedule.appointment_types.active.find_by(id: appointment_type_id)
  end

  def parse_in_zone(val, tz)
    return val.in_time_zone(tz) if val.is_a?(Time) || val.is_a?(ActiveSupport::TimeWithZone)

    str = val.to_s.strip
    return nil if str.blank?

    if str =~ /\A\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}(:\d{2})?\z/
      tz.parse(str)
    else
      Time.zone.parse(str)&.in_time_zone(tz)
    end
  rescue ArgumentError
    nil
  end

  def resolve_or_create_contact(contact_id:, name:, email:, phone:)
    if contact_id.present?
      found = @account.contacts.find_by(id: contact_id)
      return found if found
    end

    clean_email = email.to_s.strip.downcase.presence
    clean_phone = phone.to_s.strip.presence

    contact = nil
    contact = @account.contacts.find_by('LOWER(email) = ?', clean_email) if clean_email
    if contact.nil? && clean_phone
      digits = clean_phone.gsub(/\D/, '')
      if digits.length >= 8
        contact = @account.contacts.where("regexp_replace(phone_number, '[^0-9]', '', 'g') LIKE ?", "%#{digits.last(9)}%").first
      end
    end

    if contact.nil? && (name.present? || clean_email.present? || clean_phone.present?)
      formatted_phone = if clean_phone.present?
                          clean_phone.start_with?('+') ? clean_phone : "+#{clean_phone.gsub(/\D/, '')}"
                        end
      contact = @account.contacts.create(
        name: name.presence || clean_email || formatted_phone || 'Cliente Agendamento',
        email: clean_email,
        phone_number: formatted_phone
      )
      contact = nil unless contact.persisted?
    end

    contact
  rescue StandardError
    nil
  end
end

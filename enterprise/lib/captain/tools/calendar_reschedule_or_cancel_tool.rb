# frozen_string_literal: true

class Captain::Tools::CalendarRescheduleOrCancelTool < Captain::Tools::BasePublicTool
  description 'Reschedule an existing appointment to a new date/time or cancel it, updating Google Calendar automatically.'
  param :action_type, type: 'string', desc: 'Must be either "reschedule" or "cancel"'
  param :appointment_identifier, type: 'string', desc: 'Appointment UID (e.g. msc-xxxx) or numeric ID'
  param :new_starts_at, type: 'string', desc: 'Required when action_type is "reschedule": new start datetime in YYYY-MM-DDTHH:MM format', required: false
  param :reason, type: 'string', desc: 'Optional reason or note for rescheduling/cancellation', required: false

  def perform(tool_context, action_type:, appointment_identifier:, new_starts_at: nil, reason: nil)
    account = @assistant.account
    ident = appointment_identifier.to_s.strip
    appointment = account.calendar_appointments.find_by(uid: ident) ||
                  (ident =~ /\A\d+\z/ ? account.calendar_appointments.find_by(id: ident.to_i) : nil)

    return "Agendamento '#{ident}' não encontrado nesta conta." unless appointment

    booking_service = Calendar::BookingService.new(account: account)

    case action_type.to_s.downcase.strip
    when 'cancel', 'cancelar'
      cancelled = booking_service.cancel!(appointment: appointment, reason: reason)
      "Agendamento #{cancelled.uid} (#{cancelled.title}) foi CANCELADO com sucesso."
    when 'reschedule', 'reagendar'
      return 'Informe new_starts_at (YYYY-MM-DDTHH:MM) para reagendar.' if new_starts_at.blank?

      updated = booking_service.reschedule!(appointment: appointment, new_starts_at: new_starts_at, notes: reason)
      d = updated.as_api_json
      "Agendamento #{d[:uid]} REAGENDADO com sucesso para #{d[:date]} das #{d[:start_time]} às #{d[:end_time]} com #{d[:professional_name]}. Link: #{d[:meeting_url]}"
    else
      'action_type inválido. Use "reschedule" ou "cancel".'
    end
  rescue Calendar::BookingService::SlotUnavailableError => e
    failure_result("Horário indisponível para reagendamento: #{e.message}", tool_context.state)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @assistant.account).capture_exception
    failure_result("Erro ao alterar agendamento: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.account.calendar_schedules.ai_bookable.exists?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end
end

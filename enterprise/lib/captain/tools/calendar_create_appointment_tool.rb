# frozen_string_literal: true

class Captain::Tools::CalendarCreateAppointmentTool < Captain::Tools::BasePublicTool
  description 'Book and confirm an appointment on a professional schedule (syncing with Google Calendar and generating a Google Meet link). Always verify slot availability first.'
  param :starts_at, type: 'string', desc: 'Exact start date and time in ISO format YYYY-MM-DDTHH:MM (e.g. 2026-10-26T14:30)'
  param :professional_slug, type: 'string', desc: 'Slug or name of the chosen professional (optional if only one exists)', required: false
  param :customer_name, type: 'string', desc: 'Customer full name', required: false
  param :customer_email, type: 'string', desc: 'Customer email address for Google Calendar invite', required: false
  param :customer_phone, type: 'string', desc: 'Customer phone/WhatsApp number', required: false
  param :title, type: 'string', desc: 'Subject or service name of the appointment', required: false
  param :notes, type: 'string', desc: 'Additional context or notes from the conversation', required: false

  def perform(tool_context, starts_at:, professional_slug: nil, customer_name: nil, customer_email: nil, customer_phone: nil, title: nil, notes: nil)
    state = tool_context.state || {}
    conversation = find_conversation(state)
    contact = find_contact(state) || conversation&.contact

    log_tool_usage('calendar_create_appointment', {
      starts_at: starts_at,
      professional_slug: professional_slug,
      conversation_id: conversation&.id
    })

    appointment = Calendar::BookingService.new(account: @assistant.account).create!(
      professional_slug: professional_slug,
      contact_id: contact&.id,
      conversation_id: conversation&.id,
      customer_name: customer_name.presence || contact&.name.presence || 'Cliente',
      customer_email: customer_email.presence || contact&.email,
      customer_phone: customer_phone.presence || contact&.phone_number,
      starts_at: starts_at,
      title: title,
      notes: notes,
      source: 'ai_agent',
      location_type: 'google_meet'
    )

    data = appointment.as_api_json
    <<~RESULT.strip
      Agendamento confirmado com sucesso!
      - Código (UID): #{data[:uid]} (ID: #{data[:id]})
      - Compromisso: #{data[:title]}
      - Profissional: #{data[:professional_name]}
      - Data e Horário: #{data[:date]} das #{data[:start_time]} às #{data[:end_time]} (#{data[:timezone]})
      - Cliente: #{data[:customer_name]} | E-mail: #{data[:customer_email].presence || 'N/A'}
      - Link da Reunião (Meet): #{data[:meeting_url].presence || 'Presencial / WhatsApp'}
      - Sincronizado com Google Agenda: #{data[:google_synced] ? 'Sim' : 'Agenda Interna Ativa'}
    RESULT
  rescue Calendar::BookingService::SlotUnavailableError => e
    failure_result("Conflito de horário: #{e.message}", tool_context.state)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @assistant.account).capture_exception
    failure_result("Não foi possível criar o agendamento: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.account.calendar_schedules.ai_bookable.exists?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end
end

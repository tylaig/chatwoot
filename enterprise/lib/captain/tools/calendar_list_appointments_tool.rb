# frozen_string_literal: true

class Captain::Tools::CalendarListAppointmentsTool < Captain::Tools::BasePublicTool
  description 'List upcoming appointments for the current customer/contact (by contact, email, or phone) and return public booking links for professionals.'
  param :query, type: 'string', desc: 'Optional customer email, phone number, or UID to search appointments', required: false

  def perform(tool_context, query: nil)
    state = tool_context.state || {}
    conversation = find_conversation(state)
    contact = find_contact(state) || conversation&.contact
    account = @assistant.account

    scope = account.calendar_appointments.includes(:calendar_schedule).where(status: %w[confirmed pending]).where('ends_at >= ?', 1.day.ago)
    q = query.to_s.strip

    appointments = if q.present?
                     scope.where('uid = :exact OR LOWER(customer_email) = :lower OR customer_phone ILIKE :like OR LOWER(customer_name) ILIKE :like',
                                 exact: q, lower: q.downcase, like: "%#{q.downcase}%").order(starts_at: :asc).limit(10)
                   elsif contact.present?
                     conds = ['contact_id = :cid']
                     params_hash = { cid: contact.id }
                     if contact.email.present?
                       conds << 'LOWER(customer_email) = :email'
                       params_hash[:email] = contact.email.downcase
                     end
                     if contact.phone_number.present?
                       conds << 'customer_phone = :phone'
                       params_hash[:phone] = contact.phone_number
                     end
                     scope.where(conds.join(' OR '), params_hash).order(starts_at: :asc).limit(10)
                   else
                     []
                   end

    public_links = account.calendar_schedules.ai_bookable.order(:id).map do |s|
      "#{s.name} (#{s.role_title.presence || 'Agenda'}): #{s.public_booking_url}"
    end

    if appointments.empty?
      return <<~EMPTY.strip
        Nenhum agendamento futuro encontrado para este cliente.
        Links públicos de agendamento disponíveis:
        #{public_links.map { |l| "- #{l}" }.join("\n")}
      EMPTY
    end

    lines = ["Encontrados #{appointments.size} agendamento(s):"]
    appointments.each do |appt|
      d = appt.as_api_json
      lines << "- ID #{d[:id]} (UID: #{d[:uid]}) | #{d[:title]} com #{d[:professional_name]} em #{d[:date]} #{d[:start_time]}-#{d[:end_time]} | Status: #{d[:status]} | Link: #{d[:meeting_url]}"
    end
    lines << "\nLinks públicos de agendamento:\n#{public_links.map { |l| "- #{l}" }.join("\n")}"
    lines.join("\n")
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @assistant.account).capture_exception
    failure_result("Erro ao listar agendamentos: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.account.calendar_schedules.ai_bookable.exists?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end
end

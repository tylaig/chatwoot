# frozen_string_literal: true

class Captain::Tools::CalendarCheckAvailabilityTool < Captain::Tools::BasePublicTool
  description 'Check available appointment slots on connected schedules (and Google Calendar) for a specific professional or across all professionals in the account. Always call this before suggesting or booking times.'
  param :date, type: 'string', desc: 'Start date in YYYY-MM-DD format (optional; defaults to today in America/Sao_Paulo)'
  param :days, type: 'number', desc: 'Number of days to inspect from date (1 to 7, default 3)', required: false
  param :professional, type: 'string', desc: 'Optional professional name or slug (omit or pass "all" to check all available professionals)', required: false

  def perform(tool_context, date: nil, days: 3, professional: nil)
    account = @assistant.account
    schedules = resolve_schedules(account, professional)
    return 'Nenhuma agenda/profissional ativo para agendamento por IA nesta conta.' if schedules.empty?

    tz = ActiveSupport::TimeZone[schedules.first.timezone] || ActiveSupport::TimeZone['America/Sao_Paulo']
    start_date_str = date.presence || Time.current.in_time_zone(tz).strftime('%Y-%m-%d')
    days_count = (days.presence || 3).to_i.clamp(1, 7)

    log_tool_usage('calendar_check_availability', { date: start_date_str, days: days_count, professional: professional })

    availability = Calendar::AvailabilityService.new(
      account: account,
      schedules: schedules
    ).available_slots(date_str: start_date_str, days: days_count)

    if availability.empty?
      return "Nenhum horário livre encontrado a partir de #{start_date_str} nos próximos #{days_count} dias. Tente consultar outra data."
    end

    lines = ["Horários disponíveis verificados em tempo real (Hoje: #{Time.current.in_time_zone(tz).strftime('%d/%m/%Y %H:%M %Z')}):"]
    availability.each do |entry|
      slot_times = entry[:slots].first(10).map { |s| s[:time] }.join(', ')
      lines << "- Profissional: #{entry[:professional_name]} (slug: #{entry[:professional_slug]}) | Data: #{entry[:date]} (#{entry[:weekday]}) | Horários livres: #{slot_times} | Link Público: #{entry[:public_booking_url]}"
    end
    lines.join("\n")
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @assistant.account).capture_exception
    failure_result("Erro ao consultar agenda: #{e.message}", tool_context.state)
  end

  def active?
    @assistant.account.calendar_schedules.ai_bookable.exists?
  end

  private

  def safe_to_run_after_new_customer_message?
    true
  end

  def resolve_schedules(account, professional)
    scope = account.calendar_schedules.ai_bookable.order(:id)
    q = professional.to_s.strip
    return scope.to_a if q.blank? || q.casecmp('all').zero? || q.casecmp('todos').zero?

    matched = scope.where('slug = :slug OR LOWER(name) ILIKE :like', slug: q.parameterize, like: "%#{q.downcase}%").to_a
    matched.presence || scope.to_a
  end
end

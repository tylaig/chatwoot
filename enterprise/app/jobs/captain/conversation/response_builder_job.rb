class Captain::Conversation::ResponseBuilderJob < ApplicationJob
  include Captain::Conversation::V1ActionClassifier
  include Captain::Conversation::V1FalsePromiseHandler
  include Captain::Conversation::V2LifecycleEvents
  include Captain::Conversation::MessageBuilder
  include Captain::Conversation::ResponseLifecycleLogging

  MAX_MESSAGE_LENGTH = 10_000
  V2_UNEXECUTED_HANDOFF_PROMISE_REGEX = %r{
    \b(?:
      j[áa]\s+solicitei\s+(?:o\s+)?atendimento|
      solicitei\s+(?:o\s+)?atendimento\s+(?:humano|com\s+a\s+nossa\s+equipe)|
      (?:seu\s+)?(?:chamado|atendimento|caso|pedido\s+de\s+(?:devolu[çc][ãa]o|reembolso|cancelamento))\b[^\n]{0,80}\bj[áa]\s+(?:est[áa]|ficou)\s+(?:registrado|na\s+fila)|
      j[áa]\s+(?:registrei|deixei|encaminhei)\b[^\n]{0,80}\b(?:equipe\s+humana|nossa\s+equipe|fila(?:\s+de\s+atendimento)?)|
      deixei\s+o\s+seu\s+(?:caso|chamado|atendimento)\s+registrado\s+para\s+a\s+nossa\s+equipe|
      encaminhei\s+o\s+seu\s+(?:caso|chamado|atendimento)\s+para\s+a\s+nossa\s+equipe
    )
  }xi
  retry_on ActiveStorage::FileNotFoundError, attempts: 3, wait: 2.seconds
  retry_on Faraday::BadRequestError, attempts: 3, wait: 2.seconds

  def perform(conversation, assistant, responding_to_message_id = nil)
    @conversation = conversation
    @inbox = conversation.inbox
    @assistant = assistant
    @responding_to_message_id = responding_to_message_id if captain_v2_enabled?

    return log_non_pending unless conversation_pending?
    return reopen_already_handed_off_conversation if already_handed_off_in_current_cycle?

    Current.executed_by = @assistant

    return generate_and_process_response unless captain_v2_enabled?

    return log_pre_generation_discard if newer_customer_message_arrived?

    generate_response_with_v2
  rescue ActiveStorage::FileNotFoundError, Faraday::BadRequestError => e
    handle_error(e)
    raise e
  rescue StandardError => e
    handle_error(e)
  ensure
    Current.executed_by = nil
  end

  private

  delegate :account, :inbox, to: :@conversation

  def generate_and_process_response
    message_history = collect_previous_messages
    @response = Captain::Llm::AssistantChatService.new(assistant: @assistant, conversation: @conversation).generate_response(
      message_history: message_history
    )
    classify_v1_response_action(message_history) if conversation_pending?
    repair_v1_false_promise_response(message_history) if conversation_pending?
    process_response
  end

  def generate_response_with_v2
    runner_service = v2_runner_service
    message_history = Captain::Conversation::MessageHistoryBuilderService.new(conversation: @conversation).perform
    @response = runner_service.generate_response(message_history: message_history)
    @run_result = runner_service.last_run_result

    @v2_handoff_tool_completed = runner_service.handoff_completed?
    return process_response if v2_handoff_tool_completed?
    return if runner_service.response_discarded? || newer_customer_message_arrived?

    process_response
  end

  def v2_runner_service
    run_options = Captain::Assistant::AgentRunnerService::RunOptions.new(
      responding_to_message_id: @responding_to_message_id
    )
    Captain::Assistant::AgentRunnerService.new(assistant: @assistant, conversation: @conversation, run_options: run_options)
  end

  def process_response
    # The V2 runner rescues its own generation errors and signals them via an error
    # response instead of raising, so the failure event must be emitted here — the
    # top-level handle_error path only sees exceptions raised outside the runner.
    record_v2_response_failure(@response['error_reason']) if v2_generation_errored?

    if v2_handoff_tool_fired?
      process_v2_handoff_response
    elsif v2_unexecuted_handoff_promise?
      process_v2_unexecuted_handoff_promise
    elsif v1_handoff_requested?
      process_v1_handoff_request
    elsif conversation_pending_or_resolved_by_tool?
      process_standard_response
    end
  end

  def process_v1_handoff_request
    # V1 only signals via the response string — no state has been touched yet. If
    # the conversation isn't pending anymore, a human took over mid-run; bail out
    # rather than posting a stale handoff message on top of their reply.
    return unless conversation_pending?

    process_v1_handoff
    record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::GENERATION_FAILURE) if v2_generation_errored?
  end

  def process_standard_response
    message = nil
    ActiveRecord::Base.transaction do
      next if captain_v2_enabled? && newer_customer_message_arrived?

      message = create_messages
      Rails.logger.info("[CAPTAIN][ResponseBuilderJob] Incrementing response usage for #{account.id}")
      account.increment_response_usage
    end
    return unless message

    resolve_conversation_if_marker_requested!
    capture_assistant_session(result_message: message, credits_consumed: 1.0)
    record_v2_response_completed(message) if captain_v2_enabled?
  end

  def conversation_pending_or_resolved_by_tool?
    conversation_pending? || @conversation.reload.resolved?
  end

  def resolve_conversation_if_marker_requested!
    return unless @response['resolve_requested']
    return if @conversation.resolved?
    return if @assistant.inactive_conversation_resolution_disabled?

    @conversation.with_captain_activity_context(reason: 'Cliente solicitou encerramento do atendimento', reason_type: :tool) do
      @conversation.resolved!
    end
    Captain::ConversationEvents.resolved(
      conversation: @conversation,
      assistant: @assistant,
      source: Captain::ConversationEvents::Sources::TOOL,
      at: Time.current
    )
  end

  def process_v2_handoff_response
    # Captain V1 infers completion from status. Captain V2 uses the completion
    # marker set inside the locked handoff.
    if captain_v2_enabled?
      return unless v2_handoff_tool_completed? || conversation_pending?

      v2_handoff_tool_completed? ? process_v2_handoff : process_v1_handoff
      record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::TOOL) unless v2_handoff_tool_completed?
    else
      conversation_pending? ? process_v1_handoff : process_v2_handoff
    end

    capture_assistant_session(result_message: @handoff_message, credits_consumed: 0.0)
  end

  def v1_handoff_requested?
    legacy_v1_handoff_token? || classifier_v1_handoff_requested?
  end

  def classifier_v1_handoff_requested?
    @response['action'] == 'handoff'
  end

  def legacy_v1_handoff_token?
    @response['response'] == 'conversation_handoff'
  end

  def v2_handoff_tool_fired? = @response['handoff_tool_called']
  def v2_handoff_tool_completed? = @v2_handoff_tool_completed == true

  def v2_unexecuted_handoff_promise?
    return false unless captain_v2_enabled?
    return false if v2_handoff_tool_fired? || v2_generation_errored?
    return false unless conversation_pending?

    text = @response['response'].to_s
    return false if text.blank?

    V2_UNEXECUTED_HANDOFF_PROMISE_REGEX.match?(text)
  end

  def process_v2_unexecuted_handoff_promise
    return unless conversation_pending?
    return if newer_customer_message_arrived?

    Rails.logger.warn(
      "[CAPTAIN][ResponseBuilderJob] V2 unexecuted handoff promise detected for account=#{account.id} " \
      "conversation=#{@conversation.display_id}; enforcing handoff"
    )
    reason = @response['reasoning'].presence ||
             'Transferência automática acionada: o assistente confirmou encaminhamento humano na resposta.'
    @conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: @assistant,
      account_id: account.id,
      inbox_id: inbox.id,
      content: reason
    )
    @response['action_source'] = 'v2_false_promise_guard'
    @response['action_reason'] = 'unexecuted_handoff_promise'
    process_v1_handoff
    record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::TOOL)
    capture_assistant_session(result_message: @handoff_message, credits_consumed: 0.0)
  end

  def process_v1_handoff
    I18n.with_locale(@assistant.account.locale) do
      Rails.logger.info(
        "[CAPTAIN][ResponseBuilderJob] V1 handoff requested for account=#{account.id} conversation=#{@conversation.display_id} " \
        "source=#{@response&.dig('action_source') || 'legacy'} reason=#{@response&.dig('action_reason')}"
      )
      create_handoff_message
      @conversation.bot_handoff!
      report_v1_handoff_not_executed if conversation_pending?
      send_out_of_office_message_if_applicable
    end
  end

  def process_v2_handoff
    # HandoffTool already ran bot_handoff! + OOO inside the agent loop. Preserve
    # waiting_since so this message doesn't clear the timestamp it left in place.
    I18n.with_locale(@assistant.account.locale) do
      create_handoff_message(preserve_waiting_since: true)
    end
  end

  def send_out_of_office_message_if_applicable
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if @conversation.campaign.present?
    return if out_of_office_handoff_message_configured?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(@conversation)
  end

  def create_handoff_message(preserve_waiting_since: false)
    return if out_of_office_message_applicable? && !out_of_office_handoff_message_configured?
    return if handoff_message_already_sent_in_current_cycle?

    @handoff_message = create_outgoing_message(
      configured_handoff_message,
      preserve_waiting_since: preserve_waiting_since
    )
  end

  def configured_handoff_message
    if out_of_office_handoff_applicable? && out_of_office_handoff_message_configured?
      return @assistant.config['out_of_office_handoff_message'].presence
    end

    @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff')
  end

  def configured_handoff_messages
    [
      @assistant.config['handoff_message'].presence || I18n.t('conversations.captain.handoff'),
      @assistant.config['out_of_office_handoff_message'].presence
    ].compact.uniq
  end

  def last_resolution_activity_at
    @conversation.messages.activity
                 .where("content ILIKE '%resolv%'")
                 .maximum(:created_at)
  end

  def handoff_message_already_sent_in_current_cycle?
    scope = @conversation.messages.outgoing.where(private: false, sender: @assistant, content: configured_handoff_messages)
    cutoff = last_resolution_activity_at
    scope = scope.where('created_at > ?', cutoff) if cutoff.present?
    scope.exists?
  end

  def already_handed_off_in_current_cycle?
    return false if @conversation.assignee_id.blank?

    handoff_message_already_sent_in_current_cycle?
  end

  def reopen_already_handed_off_conversation
    Rails.logger.info(
      "[CAPTAIN][ResponseBuilderJob] Reopening already handed-off conversation=#{@conversation.display_id} " \
      "for assignee_id=#{@conversation.assignee_id} without duplicate bot handoff"
    )
    @conversation.open! if @conversation.pending?
  end

  def out_of_office_handoff_message_configured?
    @assistant.config['out_of_office_handoff_message'].present?
  end

  def out_of_office_handoff_applicable?
    @conversation.campaign.blank? && inbox_or_business_hours_out_of_office?
  end

  def inbox_or_business_hours_out_of_office?
    return @inbox.out_of_office? if @inbox.working_hours_enabled?

    now_brt = Time.current.in_time_zone(@inbox.timezone.presence || 'America/Sao_Paulo')
    now_brt.hour < 11 || now_brt.hour >= 22
  end

  def out_of_office_message_applicable?
    @conversation.campaign.blank? && @inbox.out_of_office? && @inbox.out_of_office_message.present?
  end

  # Capture runs outside the delivery transaction and never raises (the service
  # swallows its own failures): a session-logging bug must never roll back the
  # customer reply or trigger the top-level handle_error handoff on top of it.
  def capture_assistant_session(result_message:, credits_consumed:)
    Captain::Assistant::SessionCaptureService.new(assistant: @assistant, conversation: @conversation, run_result: @run_result,
                                                  result_message: result_message, credits_consumed: credits_consumed).capture
  end

  def handle_error(error)
    log_error(error)
    @response ||= {}
    @response['action_source'] ||= 'error'
    @response['action_reason'] ||= error_action_reason(error)
    record_v2_response_failure(error_action_reason(error)) if captain_v2_enabled?
    process_error_handoff
    true
  end

  def process_error_handoff
    return unless conversation_pending?
    return if captain_v2_enabled? && newer_customer_message_arrived?

    process_v1_handoff
    record_v2_failure_handoff(source: Captain::ConversationEvents::Sources::GENERATION_FAILURE) if captain_v2_enabled?
  end

  def log_error(error)
    ChatwootExceptionTracker.new(error, account: account).capture_exception
  end

  def error_action_reason(error)
    error.class.name.underscore.tr('/', '_')
  end

  def captain_v2_enabled?
    account.feature_enabled?('captain_integration_v2')
  end

  def report_v1_handoff_not_executed
    error = StandardError.new("Captain V1 handoff requested but conversation #{@conversation.display_id} is still pending")
    ChatwootExceptionTracker.new(error, account: account).capture_exception
    Rails.logger.error(
      "[CAPTAIN][ResponseBuilderJob] V1 handoff requested but not executed for account=#{account.id} " \
      "conversation=#{@conversation.display_id}"
    )
  end

  def newer_customer_message_arrived?
    return false if @responding_to_message_id.blank?

    Conversation.uncached do
      @conversation.messages
                   .captain_response_triggering
                   .exists?(['messages.id > ?', @responding_to_message_id])
    end
  end
end

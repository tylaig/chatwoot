class Captain::InboxPendingConversationsResolutionJob < ApplicationJob
  CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON = 'sem dúvidas pendentes'.freeze
  CAPTAIN_INFERENCE_HANDOFF_ACTIVITY_REASON = 'necessita atendimento humano'.freeze
  CAPTAIN_INFERENCE_SNOOZE_ACTIVITY_REASON = 'aguardando resposta do cliente'.freeze
  CAPTAIN_INACTIVITY_SNOOZE_KEY = 'captain_awaiting_reply_snoozed_at'.freeze
  queue_as :low

  def perform(inbox)
    @captain_assistant = inbox.captain_assistant
    return if captain_assistant.blank? || captain_assistant.inactive_conversation_resolution_disabled?

    @inactivity_cutoff_time = Time.current - captain_assistant.inactivity_threshold_minutes.minutes

    if evaluate_conversation_completion?(inbox.account)
      perform_with_evaluation(inbox)
    else
      perform_time_based(inbox)
    end

    resolve_expired_snoozed_conversations(inbox)
  ensure
    Current.reset
  end

  private

  attr_reader :captain_assistant, :inactivity_cutoff_time

  def evaluate_conversation_completion?(account)
    account.feature_enabled?('captain_tasks') && captain_assistant.evaluate_inactive_conversations_before_resolving?
  end

  def perform_time_based(inbox)
    Current.executed_by = captain_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      resolve_time_based_conversation(conversation, inbox)
    end
  end

  def perform_with_evaluation(inbox)
    Current.executed_by = captain_assistant

    resolvable_pending_conversations(inbox).each do |conversation|
      evaluation = evaluate_conversation(conversation, inbox)
      next unless still_resolvable_after_evaluation?(conversation)

      if evaluation[:complete] || evaluation[:status] == 'complete'
        resolve_conversation(conversation, inbox, evaluation[:reason])
      elsif evaluation[:status] == 'awaiting_customer_reply'
        snooze_conversation_for_customer_reply(conversation, evaluation[:reason])
      else
        handoff_conversation(conversation, evaluation[:reason])
      end
    end
  end

  def resolve_expired_snoozed_conversations(inbox)
    Current.executed_by = captain_assistant

    resolvable_snoozed_conversations(inbox).each do |conversation|
      resolve_snoozed_conversation_for_inactivity(conversation)
    end
  end

  def evaluate_conversation(conversation, inbox)
    Captain::ConversationCompletionService.new(
      account: inbox.account,
      conversation_display_id: conversation.display_id
    ).perform
  end

  def resolvable_pending_conversations(inbox)
    inbox.conversations.pending
         .where('last_activity_at < ?', inactivity_cutoff_time)
         .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def resolvable_snoozed_conversations(inbox)
    inbox.conversations.snoozed
         .where(snoozed_until: nil)
         .where('last_activity_at < ?', inactivity_cutoff_time)
         .where(
           "assignee_agent_bot_id = :assistant_id OR (additional_attributes ->> :snooze_key) IS NOT NULL",
           assistant_id: captain_assistant.id,
           snooze_key: CAPTAIN_INACTIVITY_SNOOZE_KEY
         )
         .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  def inactive_for_initial_action?(conversation) = conversation.last_activity_at < inactivity_cutoff_time

  def still_resolvable_after_evaluation?(conversation)
    conversation.reload
    conversation.pending? && inactive_for_initial_action?(conversation)
  rescue ActiveRecord::RecordNotFound
    false
  end

  def resolve_time_based_conversation(conversation, _inbox)
    resolved = false
    conversation.with_lock do
      conversation.reload
      next unless conversation.pending? && inactive_for_initial_action?(conversation)

      create_resolution_message(conversation)
      conversation.resolved!
      resolved = true
    end
    return unless resolved

    Captain::ConversationEvents.resolved(
      conversation: conversation,
      assistant: captain_assistant,
      source: Captain::ConversationEvents::Sources::TIME_BASED,
      at: Time.current
    )
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resolve_conversation(conversation, _inbox, reason)
    resolved = with_inference_activity_context(conversation, CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON) do
      perform_locked_transition(conversation) do
        conversation.resolved!
        create_private_note(conversation, "Resolução automática: #{reason}")
        create_resolution_message(conversation)
      end
    end
    record_inference_resolution(conversation) if resolved
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resolve_snoozed_conversation_for_inactivity(conversation)
    reason = 'Cliente não respondeu à solicitação de dados dentro do prazo de espera (inatividade após adiamento).'
    resolved = with_inference_activity_context(conversation, CAPTAIN_INFERENCE_RESOLVE_ACTIVITY_REASON) do
      conversation.with_lock do
        conversation.reload
        next false unless conversation.snoozed? && conversation.snoozed_until.nil? && inactive_for_initial_action?(conversation)

        updated_attrs = (conversation.additional_attributes || {}).except(CAPTAIN_INACTIVITY_SNOOZE_KEY)
        conversation.update!(status: :resolved, additional_attributes: updated_attrs)
        create_private_note(conversation, "Resolução automática por inatividade: #{reason}")
        create_resolution_message(conversation)
        true
      end
    end
    record_inference_resolution(conversation) if resolved
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def record_inference_resolution(conversation)
    Captain::ConversationEvents.resolved(
      conversation: conversation,
      assistant: captain_assistant,
      source: Captain::ConversationEvents::Sources::INFERENCE,
      at: Time.current
    )
  end

  def handoff_conversation(conversation, reason)
    handed_off = with_inference_activity_context(conversation, CAPTAIN_INFERENCE_HANDOFF_ACTIVITY_REASON) do
      perform_locked_transition(conversation) do
        conversation.bot_handoff!(dispatch_event: false)
        create_private_note(conversation, "Transferência automática: #{reason}")
        create_handoff_message(conversation)
      end
    end
    return unless handed_off

    conversation.dispatch_bot_handoff_event
    Captain::ConversationEvents.handed_off(
      conversation: conversation,
      assistant: captain_assistant,
      source: Captain::ConversationEvents::Sources::INFERENCE,
      reason_category: :pending_clarification,
      at: Time.current
    )
    send_out_of_office_message_if_applicable(conversation.reload)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def snooze_conversation_for_customer_reply(conversation, reason)
    with_inference_activity_context(conversation, CAPTAIN_INFERENCE_SNOOZE_ACTIVITY_REASON) do
      perform_locked_transition(conversation) do
        updated_attrs = (conversation.additional_attributes || {}).merge(
          CAPTAIN_INACTIVITY_SNOOZE_KEY => Time.current.iso8601
        )
        conversation.ai_assignee = captain_assistant if conversation.assignee_id.blank?
        conversation.additional_attributes = updated_attrs
        conversation.snoozed_until = nil
        conversation.snoozed!
        create_private_note(conversation, "Aguardando resposta do cliente (adiada): #{reason}")
      end
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def perform_locked_transition(conversation)
    conversation.with_lock do
      conversation.reload
      next false unless conversation.pending? && inactive_for_initial_action?(conversation)

      yield
      true
    end
  end

  def with_inference_activity_context(conversation, reason, &)
    conversation.with_captain_activity_context(reason: reason, reason_type: :inference, &)
  end

  def send_out_of_office_message_if_applicable(conversation)
    return if out_of_office_handoff_message_configured?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation) if conversation.campaign.blank?
  end

  def create_private_note(conversation, content)
    conversation.messages.create!(
      message_type: :outgoing,
      private: true,
      sender: captain_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: content
    )
  end

  def create_resolution_message(conversation)
    Captain::Conversation::ResolutionMessageService.new(
      conversation: conversation,
      assistant: captain_assistant
    ).perform(use_default_message: true)
  end

  def create_handoff_message(conversation)
    return if out_of_office_message_applicable?(conversation) && !out_of_office_handoff_message_configured?

    handoff_message = configured_handoff_message_for(conversation)
    return if handoff_message.blank?

    conversation.messages.create!(
      message_type: :outgoing,
      sender: captain_assistant,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      content: handoff_message,
      preserve_waiting_since: true
    )
  end

  def configured_handoff_message_for(conversation)
    if out_of_office_handoff_applicable?(conversation) && out_of_office_handoff_message_configured?
      return captain_assistant.config['out_of_office_handoff_message']
    end

    captain_assistant.config['handoff_message']
  end

  def out_of_office_handoff_message_configured?
    captain_assistant.config['out_of_office_handoff_message'].present?
  end

  def out_of_office_handoff_applicable?(conversation)
    inbox = conversation.inbox
    return false if conversation.campaign.present?
    return inbox.out_of_office? if inbox.working_hours_enabled?

    now_brt = Time.current.in_time_zone(inbox.timezone.presence || 'America/Sao_Paulo')
    now_brt.hour < 11 || now_brt.hour >= 22
  end

  def out_of_office_message_applicable?(conversation)
    inbox = conversation.inbox
    conversation.campaign.blank? && inbox.out_of_office? && inbox.out_of_office_message.present?
  end
end

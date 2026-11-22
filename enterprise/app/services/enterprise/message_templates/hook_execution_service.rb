module Enterprise::MessageTemplates::HookExecutionService
  def trigger_templates
    super
    return unless captain_conversation_message?

    # Eligibility is demand-level: every inbound customer message in a
    # Captain-connected inbox counts, including conversations a human grabbed
    # first or that arrive while the account is over its usage limit —
    # otherwise the coverage denominator only ever contains conversations
    # Captain was already about to answer.
    track_captain_eligibility
    return unless prepare_captain_conversation
    return perform_handoff unless inbox.captain_active?

    Captain::Conversation::ResponseSchedulerService.new(message: message).perform
  end

  def should_send_greeting?
    return false if captain_handling_conversation?

    super
  end

  def should_send_out_of_office_message?
    return false if captain_handling_conversation?

    super
  end

  def should_send_email_collect?
    return false if captain_handling_conversation?

    super
  end

  private

  def track_captain_eligibility
    return unless conversation.account.feature_enabled?('captain_integration_v2')

    Captain::ConversationOutcomeTracker.new(
      conversation: conversation,
      assistant: inbox.captain_assistant
    ).record_eligibility(at: message.created_at)
  end

  def captain_conversation_message?
    message.captain_response_triggering? && captain_assistant_configured? && !inbox.external_bot_active?
  end

  def perform_handoff
    Rails.logger.info("Captain limit exceeded, performing handoff mid-conversation for conversation: #{conversation.id}")
    conversation.messages.create!(
      message_type: :outgoing,
      account_id: conversation.account.id,
      inbox_id: conversation.inbox.id,
      content: 'Transferring to another agent for further assistance.'
    )
    conversation.bot_handoff!
    Captain::ConversationEvents.handed_off(
      conversation: conversation,
      assistant: inbox.captain_assistant,
      source: Captain::ConversationEvents::Sources::USAGE_LIMIT,
      reason_category: :usage_limit,
      at: Time.current
    )
    send_out_of_office_message_after_handoff
  end

  def send_out_of_office_message_after_handoff
    # Campaign conversations should never receive OOO templates — the campaign itself
    # serves as the initial outreach, and OOO would be confusing in that context.
    return if conversation.campaign.present?

    ::MessageTemplates::Template::OutOfOffice.perform_if_applicable(conversation)
  end

  def captain_handling_conversation?
    conversation.pending? && captain_assistant_configured?
  end

  # A conversation can be created as open when Captain is bound after the
  # conversation lifecycle callback runs. Promote only unassigned conversations
  # that the assistant is allowed to handle; never steal a human-owned thread
  # and never bypass the assistant's business-hours policy.
  def prepare_captain_conversation
    # Incoming messages can race with auto-resolution and arrive while the
    # conversation is still awaiting_resolution. Treat that state like open
    # here: only unassigned conversations are eligible, and the lock below
    # makes the promotion idempotent without stealing human-owned threads.
    return true if conversation.pending?
    return false unless (conversation.open? || conversation.awaiting_resolution?) &&
                        conversation.assignee_id.blank? && conversation.ai_assignee.blank?

    assistant = inbox.captain_assistant
    return false unless assistant&.engages?(contact, conversation)

    conversation.with_lock do
      conversation.reload
      next false unless (conversation.open? || conversation.awaiting_resolution?) &&
                          conversation.assignee_id.blank? && conversation.ai_assignee.blank?

      conversation.ai_assignee = assistant
      conversation.status = :pending
      conversation.save!
      true
    end
  end

  def captain_assistant_configured?
    inbox.captain_assistant.present?
  end
end

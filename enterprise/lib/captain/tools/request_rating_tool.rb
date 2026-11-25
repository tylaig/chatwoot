class Captain::Tools::RequestRatingTool < Captain::Tools::BasePublicTool
  description 'REQUIRED before mentioning star ratings to the customer. Sends the interactive CSAT star card in the conversation. ' \
              'Call this whenever you thank the customer, close the help request, or say that rating stars are available below. ' \
              'Never claim that stars are "logo abaixo" without calling this tool first.'
  param :reason, type: 'string', desc: 'Brief context or reason for requesting the rating (optional)', required: false

  def perform(tool_context, reason: nil)
    conversation = find_conversation(tool_context.state)
    return failure_result('Conversation not found', tool_context.state) unless conversation

    log_tool_usage('request_rating', { conversation_id: conversation.id, reason: reason })

    if conversation.messages.where(content_type: :input_csat).exists?
      return "CSAT rating survey was already sent in Conversation ##{conversation.display_id}"
    end

    result = ::CsatSurveyService.new(conversation: conversation, force: true).perform
    return failure_result("Unable to send CSAT survey (#{result})", tool_context.state) if result == :not_eligible

    "Interactive CSAT rating survey sent to customer in Conversation ##{conversation.display_id}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
    failure_result('Failed to send CSAT rating survey', tool_context.state)
  end

  private

  def permissions
    %w[conversation_manage conversation_unassigned_manage conversation_participating_manage]
  end
end

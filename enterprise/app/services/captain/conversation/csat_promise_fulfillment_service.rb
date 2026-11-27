# When Captain promises a star rating in plain text ("estrelinhas logo abaixo")
# but forgets to call request_rating, the interactive CSAT card never appears.
# This safety net detects that promise and delivers the survey with force: true
# so the customer sees the stars that were just advertised.
class Captain::Conversation::CsatPromiseFulfillmentService
  pattr_initialize [:conversation!, { content: nil }]

  CSAT_PROMISE_PATTERN = /
    estrelinha|
    estrelas?\s+(?:logo\s+)?abaixo|
    cart[aã]o\s+de\s+avalia|
    avalia(?:r|ção)?\s+(?:o\s+)?(?:meu\s+|nosso\s+)?atendimento|
    deixei\s+a\s+avalia|
    avalia(?:r|ção)\s+em\s+estrel
  /xi

  def perform
    return :skipped if content_to_scan.blank?
    return :skipped if Captain::Conversation::HumanHandoffLock.locked?(conversation)
    return :skipped unless promises_csat?
    return :skipped unless conversation.inbox.csat_survey_enabled?
    return :already_sent if conversation.messages.where(content_type: :input_csat).exists?

    result = CsatSurveyService.new(conversation: conversation, force: true).perform
    return :not_eligible if result == :not_eligible
    return :blocked_by_survey_rules if result == :blocked_by_survey_rules

    :sent
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    :error
  end

  private

  def content_to_scan
    content.presence || conversation.messages.outgoing.where(private: false).order(id: :desc).limit(1).pick(:content)
  end

  def promises_csat?
    content_to_scan.to_s.match?(CSAT_PROMISE_PATTERN)
  end
end

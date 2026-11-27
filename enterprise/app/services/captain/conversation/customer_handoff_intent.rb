# Detects when the customer is explicitly asking to leave the bot —
# human agent, refund, or legal escalation. Matched before the LLM runs so
# Captain cannot keep troubleshooting after the customer already asked out.
class Captain::Conversation::CustomerHandoffIntent
  PATTERN = %r{
    \b(?:
      falar\s+com\s+(?:um\s+)?(?:atendente|humano|operador)|
      atendente\s+humano|
      pessoa\s+real|
      quero\s+(?:um\s+)?humano|
      precisa(?:va)?\s+de\s+(?:um\s+)?(?:atendente|humano)|
      me\s+passa\s+(?:pro|para\s+o|pro)\s+atendente|
      me\s+transf|
      solicitar\s+reembolso|
      quero\s+(?:o\s+)?reembolso|
      pedir\s+reembolso|
      cancelar\s+(?:a\s+)?compra|
      procon|
      procom|
      estelionato|
      processo\s+no\s+procon
    )\b
  }xi

  class << self
    def detected?(text)
      text.to_s.match?(PATTERN)
    end

    def matching_message(conversation)
      conversation.messages
                  .captain_response_triggering
                  .order(id: :desc)
                  .limit(5)
                  .detect { |message| detected?(message.content) }
    end
  end
end

class CsatSurveys::ResponseBuilder
  pattr_initialize [:message]

  def perform
    raise 'Invalid Message' unless message.input_csat?

    conversation = message.conversation
    rating = message.content_attributes.dig('submitted_values', 'csat_survey_response', 'rating')
    feedback_message = message.content_attributes.dig('submitted_values', 'csat_survey_response', 'feedback_message')

    return if rating.blank?

    process_csat_response(conversation, rating, feedback_message)
  end

  private

  def process_csat_response(conversation, rating, feedback_message)
    resolved_agent = conversation.assignee || last_human_agent_before_message(conversation)
    csat_survey_response = message.csat_survey_response || CsatSurveyResponse.new(
      message_id: message.id, account_id: message.account_id, conversation_id: message.conversation_id,
      contact_id: conversation.contact_id, assigned_agent: resolved_agent
    )
    csat_survey_response.assigned_agent ||= resolved_agent
    previous_feedback = csat_survey_response.feedback_message
    csat_survey_response.rating = rating
    csat_survey_response.feedback_message = feedback_message
    csat_survey_response.save!

    create_low_rating_private_note(conversation, rating, feedback_message) if should_create_private_note?(rating, feedback_message, previous_feedback)

    csat_survey_response
  end

  def last_human_agent_before_message(conversation)
    last_msg = conversation.messages.where(sender_type: 'User', private: false).where('id < ?', message.id).order(:id).last
    last_msg&.sender
  end

  def should_create_private_note?(rating, feedback_message, previous_feedback)
    rating.to_i <= 3 && feedback_message.present? && feedback_message != previous_feedback
  end

  def create_low_rating_private_note(conversation, rating, feedback_message)
    stars = '⭐' * rating.to_i
    note_content = "⚠️ **Feedback Interno CSAT (#{rating}/5 #{stars}):**\n#{feedback_message}"
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      sender: conversation.assignee,
      content: note_content
    )
  rescue StandardError => e
    Rails.logger.error "Failed to create CSAT private note for conversation #{conversation.id}: #{e.message}"
  end
end

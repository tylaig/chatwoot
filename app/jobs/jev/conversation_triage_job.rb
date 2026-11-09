# frozen_string_literal: true

module Jev
  class ConversationTriageJob < ApplicationJob
    queue_as :high

    def perform(conversation_id, message_id)
      conversation = Conversation.find_by(id: conversation_id)
      message = Message.find_by(id: message_id)
      return unless conversation && message
      return unless message.incoming? && !message.private?
      return if message.content.to_s.strip.length < 3

      triage = Jev::DecisionService.triage_message(message.content)
      return if triage.blank?

      msg_attrs = (message.additional_attributes || {}).merge('jev_triage' => triage)
      message.update_columns(additional_attributes: msg_attrs, updated_at: Time.current)

      conv_attrs = (conversation.additional_attributes || {}).merge('jev_triage' => triage)
      conversation.update_columns(additional_attributes: conv_attrs, updated_at: Time.current)

      Rails.configuration.dispatcher.dispatch(
        Events::Types::CONVERSATION_UPDATED,
        Time.zone.now,
        conversation: conversation,
        changed_attributes: { 'additional_attributes' => [nil, conv_attrs] }
      )
    rescue StandardError => e
      Rails.logger.warn("[JEV][ConversationTriageJob] Error on conv=#{conversation_id}: #{e.message}")
    end
  end
end

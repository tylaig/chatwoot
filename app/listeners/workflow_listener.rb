# frozen_string_literal: true

class WorkflowListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return if message.blank?

    Workflows::NativeTriggerService.new(
      event_name: 'message_created',
      account: message.account,
      conversation: message.conversation,
      message: message
    ).perform
  end

  def conversation_created(event)
    conversation = event.data[:conversation]
    return if conversation.blank?

    Workflows::NativeTriggerService.new(
      event_name: 'conversation_created',
      account: conversation.account,
      conversation: conversation
    ).perform
  end

  def conversation_opened(event)
    conversation = event.data[:conversation]
    return if conversation.blank?

    Workflows::NativeTriggerService.new(
      event_name: 'conversation_reopened',
      account: conversation.account,
      conversation: conversation,
      previous_status: previous_status_name(event)
    ).perform
  end

  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    return if contact_inbox.blank?

    Workflows::NativeTriggerService.new(
      event_name: 'webwidget_triggered',
      account: contact_inbox.inbox.account,
      contact_inbox: contact_inbox
    ).perform
  end

  private

  def previous_status_name(event)
    changes = event.data[:changed_attributes]
    raw = changes.is_a?(Hash) ? (changes[:status] || changes['status']) : nil
    previous = raw.is_a?(Array) ? raw.first : nil
    return if previous.nil?
    return previous.to_s if Conversation.statuses.key?(previous.to_s)

    Conversation.statuses.key(previous.to_i)
  end
end

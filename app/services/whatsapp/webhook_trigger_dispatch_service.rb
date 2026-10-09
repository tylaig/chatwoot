# frozen_string_literal: true

class Whatsapp::WebhookTriggerDispatchService
  pattr_initialize [:trigger!, :phone_number!, :contact_name, :template_params!, :labels]

  def perform
    inbox = trigger.inbox
    account = trigger.account

    normalized_phone = normalize_phone_number(phone_number)
    contact = find_or_create_contact(account, normalized_phone)
    contact_inbox = find_or_create_contact_inbox(contact, inbox, normalized_phone)

    conversation = find_or_create_conversation(account, inbox, contact, contact_inbox)

    # Attach labels if provided
    attach_labels(conversation, account) if labels.present?

    # Create message with template payload
    message = conversation.messages.create!(
      account_id: account.id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      status: :sent,
      content: "Template: #{trigger.template_name}",
      additional_attributes: {
        template_params: template_params,
        webhook_trigger_id: trigger.id
      }
    )

    # Send through official WhatsApp Channel
    Whatsapp::SendOnWhatsappService.new(message: message).perform

    {
      success: true,
      conversation_id: conversation.display_id,
      contact_id: contact.id,
      message_id: message.id
    }
  rescue StandardError => e
    Rails.logger.error "[WebhookTriggerDispatchService] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    { success: false, error: e.message }
  end

  private

  def normalize_phone_number(phone)
    raw = phone.to_s.gsub(/\D/, '')
    raw = "55#{raw}" if raw.length.between?(10, 11) && !raw.start_with?('55')
    "+#{raw}"
  end

  def find_or_create_contact(account, phone)
    contact = account.contacts.find_by(phone_number: phone)
    return contact if contact.present?

    account.contacts.create!(
      name: contact_name.presence || 'Cliente',
      phone_number: phone
    )
  end

  def find_or_create_contact_inbox(contact, inbox, phone)
    contact_inbox = ContactInbox.find_by(contact_id: contact.id, inbox_id: inbox.id)
    return contact_inbox if contact_inbox.present?

    ContactInbox.create!(
      contact_id: contact.id,
      inbox_id: inbox.id,
      source_id: phone
    )
  end

  def find_or_create_conversation(account, inbox, contact, contact_inbox)
    conversation = inbox.conversations.where(contact_id: contact.id).last

    if conversation.blank? || conversation.resolved?
      conversation = Conversation.create!(
        account_id: account.id,
        inbox_id: inbox.id,
        contact_id: contact.id,
        contact_inbox_id: contact_inbox.id,
        status: :open
      )
    end

    conversation
  end

  def attach_labels(conversation, account)
    valid_labels = account.labels.where(title: labels).pluck(:title)
    conversation.add_labels(valid_labels) if valid_labels.present?
  end
end

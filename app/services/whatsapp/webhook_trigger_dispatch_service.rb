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

      #Create message with template payload
    rendered_content = render_template_content(trigger.template_name, template_params, inbox)
    message = conversation.messages.create!(
      account_id: account.id,
      inbox_id: inbox.id,
      message_type: :outgoing,
      status: :sent,
      content: rendered_content,
      additional_attributes: {
        template_params: template_params,
        webhook_trigger_id: trigger.id
      }
    )

    # Send through appropriate channel
    if inbox.channel.is_a?(Channel::Whatsapp)
      Whatsapp::SendOnWhatsappService.new(message: message).perform
    elsif inbox.channel.respond_to?(:send_message)
      inbox.channel.send_message(message)
    end

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

    source_id = inbox.channel_type == 'Channel::Whatsapp' ? phone.to_s.delete_prefix('+').gsub(/\D/, '') : phone
    existing_by_source = ContactInbox.find_by(inbox_id: inbox.id, source_id: source_id)
    return existing_by_source if existing_by_source.present?

    ContactInbox.create!(
      contact_id: contact.id,
      inbox_id: inbox.id,
      source_id: source_id
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

    conversation.open! unless conversation.open?
    conversation
  end

  def render_template_content(template_name, tpl_params, inbox)
    scope = inbox.account.whatsapp_templates.where(name: template_name)
    tpl = scope.find_by(inbox_id: inbox.id) || scope.first
    body_text = tpl&.body.to_s
    if body_text.blank? && inbox.channel.respond_to?(:message_templates)
      cached = Array(inbox.channel.message_templates).find { |item| item['name'] == template_name }
      body_text = Array(cached&.dig('components')).find { |c| c['type'] == 'BODY' }&.dig('text').to_s
    end
    return "Template: #{template_name}" if body_text.blank?

    body_vars = tpl_params.to_h.dig(:processed_params, :body) || tpl_params.to_h.dig('processed_params', 'body') || {}
    rendered = body_text.dup
    body_vars.each do |k, v|
      rendered.gsub!(/\{\{\s*#{Regexp.escape(k.to_s)}\s*\}\}/, v.to_s)
    end
    rendered
  end

  def attach_labels(conversation, account)
    valid_labels = account.labels.where(title: labels).pluck(:title)
    conversation.add_labels(valid_labels) if valid_labels.present?
  end
end

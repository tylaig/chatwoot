# frozen_string_literal: true

class WebhookDispatchTrigger < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :workflow, optional: true

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(active: true) }

  def execute_payload(payload)
    parsed_phone = extract_by_path(payload, field_mapping['phone_path'])
    parsed_name = extract_by_path(payload, field_mapping['name_path'])

    return { error: 'Telefone não encontrado no mapeamento do payload' } if parsed_phone.blank?

    normalized_phone = normalize_phone_number(parsed_phone)
    contact = find_or_create_contact(account, normalized_phone, parsed_name)
    contact_inbox = find_or_create_contact_inbox(contact, inbox, normalized_phone)
    conversation = find_or_create_conversation(account, inbox, contact, contact_inbox)

    # If trigger is associated with a Workflow and active, start the workflow execution
    if workflow.present? && workflow.status == 'active' && workflow.active_version.present?
      execution = account.workflow_executions.create!(
        workflow: workflow,
        workflow_version: workflow.active_version,
        contact: contact,
        conversation: conversation,
        inbox: inbox,
        trigger_type: 'webhook',
        idempotency_key: "whk_exec_#{id}_#{Time.current.to_i}_#{SecureRandom.hex(4)}",
        status: 'running',
        started_at: Time.current,
        context: {
          webhook: {
            trigger_id: id,
            trigger_name: name,
            payload: payload
          },
          payload: payload
        }
      )

      # Start execution asynchronously via Sidekiq job
      WorkflowExecutionJob.perform_later(execution.id)

      return {
        success: true,
        workflow_id: workflow.id,
        workflow_execution_id: execution.id,
        conversation_id: conversation.display_id,
        contact_id: contact.id
      }
    end

    # Fallback to direct single template dispatch
    template_params = build_template_parameters(payload)

    Whatsapp::WebhookTriggerDispatchService.new(
      trigger: self,
      phone_number: parsed_phone.to_s,
      contact_name: parsed_name.to_s.presence || 'Cliente',
      template_params: template_params,
      labels: field_mapping['labels'] || []
    ).perform
  end

  def extract_by_path(data, path)
    return nil if data.blank? || path.blank?

    hash_data = data.respond_to?(:to_unsafe_h) ? data.to_unsafe_h : data
    keys = path.to_s.split('.')
    current = hash_data.respond_to?(:with_indifferent_access) ? hash_data.with_indifferent_access : hash_data

    keys.each do |key|
      return nil unless current.is_a?(Hash) || current.is_a?(Array)

      current = if current.is_a?(Array) && key.match?(/^\d+$/)
                  current[key.to_i]
                elsif current.is_a?(Hash)
                  current[key]
                else
                  nil
                end
    end
    current
  end

  private

  def generate_token
    self.token ||= "whk_#{SecureRandom.hex(16)}"
  end

  def normalize_phone_number(phone)
    raw = phone.to_s.gsub(/\D/, '')
    raw = "55#{raw}" if raw.length.between?(10, 11) && !raw.start_with?('55')
    "+#{raw}"
  end

  def find_or_create_contact(account, phone, name)
    contact = account.contacts.find_by(phone_number: phone)
    return contact if contact.present?

    account.contacts.create!(
      name: name.presence || 'Cliente',
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

  def build_template_parameters(payload)
    mapping_params = field_mapping['parameters'] || []
    body_params = {}

    mapping_params.each_with_index do |param, index|
      value = if param['type'] == 'static'
                param['value']
              else
                extract_by_path(payload, param['value'])
              end
      body_params[(index + 1).to_s] = (value || '')
    end

    {
      name: template_name,
      category: 'UTILITY',
      language: template_language.presence || 'pt_BR',
      processed_params: {
        body: body_params
      }
    }
  end
end

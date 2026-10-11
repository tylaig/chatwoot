# frozen_string_literal: true

class WebhookDispatchTrigger < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :workflow, optional: true

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_defaults, on: :create

  scope :active, -> { where(active: true) }

  private

  def set_defaults
    self.dispatch_mode ||= (workflow_id.present? ? 'workflow' : 'template')
    self.template_name ||= (workflow_id.present? ? 'workflow_dispatch' : 'default_template')
    self.template_language ||= 'pt_BR'
    self.field_mapping ||= {}
    self.sample_payload ||= {}
  end

  public

  def execute_payload(payload)
    parsed_phone = extract_by_path(payload, field_mapping['phone_path'])
    parsed_name = extract_by_path(payload, field_mapping['name_path'])

    return { error: 'Telefone não encontrado no mapeamento do payload' } if parsed_phone.blank?

    normalized_phone = normalize_phone_number(parsed_phone)
    contact = find_or_create_contact(account, normalized_phone, parsed_name)
    apply_contact_custom_attributes!(contact, payload)
    contact_inbox = find_or_create_contact_inbox(contact, inbox, normalized_phone)
    conversation = find_or_create_conversation(account, inbox, contact, contact_inbox)

    # If trigger is associated with a Workflow and active, start the workflow execution
    if workflow.present? && workflow.status == 'active' && workflow.active_version.present?
      # Idempotency determination: use event_id, id, or hash of payload
      event_id = extract_by_path(payload, 'event_id') || extract_by_path(payload, 'id')
      idemp_key = if event_id.present?
                    "whk_exec_#{id}_#{event_id}"
                  else
                    "whk_exec_#{id}_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
                  end

      # Check existing execution with this idempotency key
      existing = account.workflow_executions.find_by(workflow: workflow, idempotency_key: idemp_key)
      if existing.present?
        return {
          success: true,
          workflow_id: workflow.id,
          workflow_execution_id: existing.id,
          conversation_id: conversation.display_id,
          contact_id: contact.id,
          note: 'idempotent_duplicate_prevented'
        }
      end

      execution = account.workflow_executions.create!(
        workflow: workflow,
        workflow_version: workflow.active_version,
        contact: contact,
        conversation: conversation,
        inbox: inbox,
        trigger_type: 'webhook',
        idempotency_key: idemp_key,
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

  def mapping_payload
    payload_pinned && pinned_payload.present? ? pinned_payload : sample_payload
  end

  def run_test_execution(payload = mapping_payload)
    return { error: 'Nenhum payload recebido para executar o teste.' } if payload.blank?
    return { error: 'O fluxo não está ligado a este webhook.' } if workflow.blank?

    parsed_phone = extract_by_path(payload, field_mapping['phone_path'])
    parsed_name = extract_by_path(payload, field_mapping['name_path'])
    return { error: 'Telefone não encontrado no mapeamento do payload' } if parsed_phone.blank?

    version = workflow.versions.drafts.order(updated_at: :desc).first || workflow.active_version
    return { error: 'O fluxo ainda não tem uma versão para executar.' } if version.blank?

    normalized_phone = normalize_phone_number(parsed_phone)
    contact = find_or_create_contact(account, normalized_phone, parsed_name)
    apply_contact_custom_attributes!(contact, payload)
    contact_inbox = find_or_create_contact_inbox(contact, inbox, normalized_phone)
    conversation = find_or_create_conversation(account, inbox, contact, contact_inbox)

    execution = account.workflow_executions.create!(
      workflow: workflow,
      workflow_version: version,
      contact: contact,
      conversation: conversation,
      inbox: inbox,
      trigger_type: 'webhook_test',
      idempotency_key: "whk_test_#{id}_#{SecureRandom.hex(4)}",
      status: 'running',
      started_at: Time.current,
      context: {
        test: true,
        webhook: { trigger_id: id, trigger_name: name, payload: payload },
        payload: payload
      }
    )
    WorkflowExecutionJob.perform_later(execution.id)

    {
      success: true,
      workflow_execution_id: execution.id,
      conversation_id: conversation.display_id,
      contact_id: contact.id
    }
  end

  def apply_contact_custom_attributes!(contact, payload)
    rows = Array(field_mapping.to_h['custom_attributes'])
    return if rows.blank?

    definitions = account.custom_attribute_definitions.contact_attribute.index_by(&:attribute_key)
    attrs = (contact.custom_attributes || {}).dup
    changed = false
    rows.each do |row|
      key = row.to_h['attribute_key'].presence
      path = row.to_h['source_path'].presence
      definition = definitions[key]
      next if key.blank? || path.blank? || definition.blank?

      value = extract_by_path(payload, path)
      next if value.nil?

      attrs[key] = coerce_attribute_value(definition.attribute_display_type, value)
      changed = true
    end
    contact.update!(custom_attributes: attrs) if changed
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

  def coerce_attribute_value(display_type, value)
    case display_type
    when 'number', 'currency', 'percent'
      value.to_s.tr(',', '.').to_f
    when 'checkbox'
      ActiveModel::Type::Boolean.new.cast(value)
    else
      value.is_a?(Hash) || value.is_a?(Array) ? value.to_json : value.to_s
    end
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

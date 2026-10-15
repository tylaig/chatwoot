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
    prepared = prepare_dispatch(payload)
    return prepared if prepared[:error]

    contact = prepared[:contact]
    conversation = prepared[:conversation]

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
        inbox: prepared[:inbox] || inbox,
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

    return { error: 'Esta caixa exige o telefone do contato.' } if prepared[:phone].blank?

    template_params = build_template_parameters(payload)

    Whatsapp::WebhookTriggerDispatchService.new(
      trigger: self,
      phone_number: prepared[:phone].to_s,
      contact_name: prepared[:name].presence || 'Cliente',
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

    version = workflow.versions.drafts.order(updated_at: :desc).first || workflow.active_version
    return { error: 'O fluxo ainda não tem uma versão para executar.' } if version.blank?

    prepared = prepare_dispatch(payload)
    return prepared if prepared[:error]

    contact = prepared[:contact]
    conversation = prepared[:conversation]

    execution = account.workflow_executions.create!(
      workflow: workflow,
      workflow_version: version,
      contact: contact,
      conversation: conversation,
      inbox: prepared[:inbox] || inbox,
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
    apply_attribute_rows!(contact, field_mapping.to_h['custom_attributes'], :contact_attribute, payload)
  end

  def mapping_report(payload)
    mapping = field_mapping.to_h
    phone = scalar_value(extract_by_path(payload, mapping['phone_path']))
    email = scalar_value(extract_by_path(payload, mapping['email_path']))
    identifier = scalar_value(extract_by_path(payload, mapping['identifier_path']))
    phone_ready = phone.present?
    identity = phone_ready || email.present? || identifier.present?
    requires_phone = inbox&.channel_type.in?(%w[Channel::Whatsapp Channel::TwilioSms])
    warnings = mapping_warnings(mapping, payload)
    warnings << 'Esta caixa exige o telefone do contato.' if requires_phone && mapping['phone_path'].present? && !phone_ready

    {
      phone: phone,
      phone_path: mapping['phone_path'],
      name: scalar_value(extract_by_path(payload, mapping['name_path'])),
      name_path: mapping['name_path'],
      email: email,
      email_path: mapping['email_path'],
      identifier: identifier,
      identifier_path: mapping['identifier_path'],
      labels: label_names(extract_by_path(payload, mapping['labels_path'])),
      labels_path: mapping['labels_path'],
      attributes: attribute_preview(mapping['custom_attributes'], :contact_attribute, payload),
      conversation_attributes: attribute_preview(mapping['conversation_attributes'], :conversation_attribute, payload),
      warnings: warnings,
      valid: identity && (!requires_phone || phone_ready)
    }
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

  def prepare_dispatch(payload)
    target_inbox = effective_inbox
    identity = mapped_identity(payload)
    error = identity_error(identity, target_inbox)
    return { error: error } if error

    contact = resolve_contact!(identity)
    apply_attribute_rows!(contact, field_mapping.to_h['custom_attributes'], :contact_attribute, payload)
    contact_inbox = find_or_create_contact_inbox(contact, target_inbox, contact_source_id(identity, target_inbox))
    conversation = find_or_create_conversation(account, target_inbox, contact, contact_inbox)
    apply_attribute_rows!(conversation, field_mapping.to_h['conversation_attributes'], :conversation_attribute, payload)
    apply_labels!(conversation, payload)
    { contact: contact, conversation: conversation, inbox: target_inbox, phone: identity[:phone], name: identity[:name] }
  end

  def effective_inbox
    node_inbox = workflow_node_inbox
    node_inbox || inbox
  end

  def workflow_node_inbox
    return if workflow.blank?

    version = workflow.active_version || workflow.versions.drafts.order(updated_at: :desc).first
    return if version.blank?

    inbox_id = Array(version.nodes).filter_map do |node|
      node.dig('data', 'config', 'inbox_id').presence || node.dig('config', 'inbox_id').presence
    end.first
    return if inbox_id.blank?

    account.inboxes.find_by(id: inbox_id)
  end

  def mapped_identity(payload)
    mapping = field_mapping.to_h
    raw_phone = scalar_value(extract_by_path(payload, mapping['phone_path']))
    raw_phone = fallback_phone_from_payload(payload) if raw_phone.blank?
    {
      phone: raw_phone.present? ? normalize_phone_number(raw_phone) : nil,
      name: scalar_value(extract_by_path(payload, mapping['name_path'])),
      email: scalar_value(extract_by_path(payload, mapping['email_path'])).presence&.downcase,
      identifier: scalar_value(extract_by_path(payload, mapping['identifier_path'])).presence
    }
  end

  def fallback_phone_from_payload(payload)
    %w[phone customer.phone shipping_address.phone billing_address.phone cliente.whatsapp cliente.telefone].each do |path|
      val = scalar_value(extract_by_path(payload, path))
      return val if val.present?
    end
    nil
  end

  def identity_error(identity, target_inbox = inbox)
    return 'Mapeie telefone, e-mail ou identificador para achar o contato.' if identity.values_at(:phone, :email, :identifier).all?(&:blank?)
    return 'Esta caixa exige o telefone do contato.' if identity[:phone].blank? && phone_required_inbox?(target_inbox)

    nil
  end

  def phone_required_inbox?(target_inbox = inbox)
    target_inbox&.channel_type.in?(%w[Channel::Whatsapp Channel::TwilioSms])
  end

  def resolve_contact!(identity)
    contact = account.contacts.find_by(phone_number: identity[:phone]) if identity[:phone].present?
    contact ||= account.contacts.where('LOWER(email) = ?', identity[:email]).first if identity[:email].present?
    contact ||= account.contacts.find_by(identifier: identity[:identifier]) if identity[:identifier].present?
    return refresh_contact!(contact, identity) if contact

    account.contacts.create!(
      name: identity[:name].presence || 'Cliente',
      phone_number: identity[:phone].presence,
      email: identity[:email].presence,
      identifier: identity[:identifier].presence
    )
  end

  def refresh_contact!(contact, identity)
    contact.name = identity[:name] if identity[:name].present?
    contact.email = identity[:email] if identity[:email].present?
    contact.identifier = identity[:identifier] if identity[:identifier].present?
    contact.phone_number = identity[:phone] if identity[:phone].present? && contact.phone_number.blank?
    contact.save! if contact.changed?
    contact
  rescue ActiveRecord::RecordInvalid
    contact.reload
  end

  def contact_source_id(identity, target_inbox = inbox)
    raw = identity[:phone].presence || identity[:email].presence || identity[:identifier].presence
    format_source_id_for_inbox(target_inbox, raw)
  end

  def format_source_id_for_inbox(target_inbox, raw_source_id)
    return raw_source_id if raw_source_id.blank? || target_inbox.blank?

    case target_inbox.channel_type
    when 'Channel::Whatsapp'
      str = raw_source_id.to_s.delete_prefix('whatsapp:').strip
      return str if str.match?(RegexHelper::WHATSAPP_BSUID_REGEX)

      str.gsub(/\D/, '')
    when 'Channel::TwilioSms'
      if target_inbox.channel.try(:medium) == 'whatsapp'
        str = raw_source_id.to_s.delete_prefix('whatsapp:').strip
        str = "+#{str.gsub(/\D/, '')}" unless str.start_with?('+') || str.match?(RegexHelper::WHATSAPP_BSUID_REGEX)
        "whatsapp:#{str}"
      else
        "+#{raw_source_id.to_s.gsub(/\D/, '')}"
      end
    else
      raw_source_id.to_s
    end
  end

  def apply_attribute_rows!(record, rows, model_name, payload)
    definitions = account.custom_attribute_definitions.public_send(model_name).index_by(&:attribute_key)
    attrs = (record.custom_attributes || {}).dup
    changed = false
    Array(rows).each do |row|
      key = row.to_h['attribute_key'].presence
      path = row.to_h['source_path'].presence
      definition = definitions[key]
      next if key.blank? || path.blank? || definition.blank?

      value = extract_by_path(payload, path)
      next if value.nil?

      attrs[key] = coerce_attribute_value(definition.attribute_display_type, value)
      changed = true
    end
    record.update!(custom_attributes: attrs) if changed
  end

  def apply_labels!(conversation, payload)
    names = label_names(extract_by_path(payload, field_mapping.to_h['labels_path']))
    conversation.add_labels(names) if names.any?
  end

  def label_names(value)
    list = value.is_a?(Array) ? value.flatten : value.to_s.split(',')
    list.map { |item| item.to_s.strip }.reject(&:blank?).uniq
  end

  def attribute_preview(rows, model_name, payload)
    definitions = account.custom_attribute_definitions.public_send(model_name).index_by(&:attribute_key)
    Array(rows).filter_map do |row|
      source = row.to_h['source_path'].presence
      key = row.to_h['attribute_key'].presence
      next if source.blank? && key.blank?

      raw = extract_by_path(payload, source)
      definition = definitions[key]
      value = definition ? coerce_attribute_value(definition.attribute_display_type, raw) : scalar_value(raw)
      { attribute_key: key, source_path: source, value: value }
    end
  end

  def mapping_warnings(mapping, payload)
    warnings = []
    if mapping.values_at('phone_path', 'email_path', 'identifier_path').all?(&:blank?)
      warnings << 'Mapeie telefone, e-mail ou identificador para achar o contato.'
    end
    %w[phone_path name_path email_path identifier_path].each do |key|
      warnings.concat(path_warnings(mapping[key], payload))
    end
    warnings.concat(label_warnings(mapping['labels_path'], payload))
    warnings.concat(row_warnings(mapping['custom_attributes'], payload))
    warnings.concat(row_warnings(mapping['conversation_attributes'], payload))
    warnings.uniq
  end

  def label_warnings(path, payload)
    return [] if path.blank?

    value = extract_by_path(payload, path)
    return ["O caminho #{path} não está no JSON de exemplo."] if value.nil?
    return ["O caminho #{path} aponta para um objeto. Escolha a lista de etiquetas."] if value.is_a?(Hash)
    return ["O caminho #{path} veio vazio no exemplo."] if label_names(value).empty?

    []
  end

  def path_warnings(path, payload)
    return [] if path.blank?

    value = extract_by_path(payload, path)
    return ["O caminho #{path} não está no JSON de exemplo."] if value.nil?
    return ["O caminho #{path} aponta para um objeto ou lista. Escolha um valor."] if value.is_a?(Hash) || value.is_a?(Array)
    return ["O caminho #{path} veio vazio no exemplo."] if value.to_s.strip.blank?

    []
  end

  def row_warnings(rows, payload)
    keys = []
    Array(rows).flat_map do |row|
      key = row.to_h['attribute_key'].to_s
      path = row.to_h['source_path'].to_s
      messages = []
      if key.present? && keys.include?(key)
        messages << "O atributo #{key} está mapeado mais de uma vez."
      end
      keys << key if key.present?
      messages + path_warnings(path, payload)
    end
  end

  def scalar_value(value)
    return if value.nil?
    return if value.is_a?(Hash) || value.is_a?(Array)

    value.to_s.strip
  end

  def normalize_phone_number(phone)
    raw = phone.to_s.gsub(/\D/, '')
    raw = "55#{raw}" if raw.length.between?(10, 11) && !raw.start_with?('55')
    "+#{raw}"
  end

  def find_or_create_contact_inbox(contact, target_inbox, source_id)
    formatted_source_id = format_source_id_for_inbox(target_inbox, source_id)
    contact_inbox = ContactInbox.find_by(contact_id: contact.id, inbox_id: target_inbox.id)
    if contact_inbox.present?
      if target_inbox.channel_type == 'Channel::Whatsapp' && !RegexHelper::WHATSAPP_CHANNEL_REGEX.match?(contact_inbox.source_id.to_s) &&
         RegexHelper::WHATSAPP_CHANNEL_REGEX.match?(formatted_source_id.to_s)
        contact_inbox.update_columns(source_id: formatted_source_id) # rubocop:disable Rails/SkipsModelValidations
      end
      return contact_inbox
    end

    existing_by_source = ContactInbox.find_by(inbox_id: target_inbox.id, source_id: formatted_source_id)
    return existing_by_source if existing_by_source.present?

    ContactInbox.create!(
      contact_id: contact.id,
      inbox_id: target_inbox.id,
      source_id: formatted_source_id
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

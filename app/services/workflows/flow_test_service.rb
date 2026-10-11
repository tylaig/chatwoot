# frozen_string_literal: true

module Workflows
  class FlowTestService
    class Error < StandardError; end

    MESSAGE_NODES = %w[
      send_message send_whatsapp_message send_whatsapp_template
      send_whatsapp_buttons send_whatsapp_list send_whatsapp_media add_private_note
    ].freeze

    def initialize(workflow)
      @workflow = workflow
      @account = workflow.account
    end

    def show
      execution = latest_execution
      { session: execution.present? ? serialize(execution) : nil }
    end

    def start!
      inbox = sandbox_inbox
      raise Error, 'Crie uma caixa de entrada para testar o fluxo.' if inbox.blank?

      cancel_active!
      conversation = sandbox_conversation(inbox)
      reset_sandbox!(conversation)
      execution = create_execution(conversation)
      ExecutionEngineService.new(execution).start!
      { session: serialize(execution.reload) }
    end

    def reply!(content:, choice_id: nil)
      execution = waiting_execution
      text = content.to_s.strip
      text = choice_title(execution, choice_id) if text.blank? && choice_id.present?
      raise Error, 'Escreva uma resposta.' if text.blank?

      create_incoming!(execution, text, choice_id)
      remember_reply!(execution, text)
      ExecutionEngineService.new(execution).resume!(pending_wait(execution).node_id, resume_event(execution, text, choice_id))
      { session: serialize(execution.reload) }
    end

    def timeout!
      execution = waiting_execution
      ExecutionEngineService.new(execution).resume!(pending_wait(execution).node_id, 'timeout')
      { session: serialize(execution.reload) }
    end

    private

    def latest_execution
      @workflow.executions.where("context ->> 'test_mode' = 'true'").order(id: :desc).first
    end

    def waiting_execution
      execution = latest_execution
      raise Error, 'Comece um teste antes de responder.' if execution.blank? || execution.status != 'waiting'

      execution
    end

    def pending_wait(execution)
      execution.wait_states.pending.order(id: :desc).first || raise(Error, 'Este teste não está aguardando resposta.')
    end

    def sandbox_inbox
      inboxes = @account.inboxes.order(:id).to_a
      inboxes.find { |inbox| inbox.channel_type == 'Channel::WebWidget' } ||
        inboxes.find { |inbox| %w[Channel::Whatsapp Channel::TwilioSms].exclude?(inbox.channel_type) } ||
        inboxes.first
    end

    def sandbox_conversation(inbox)
      contact = sandbox_contact
      contact_inbox = ContactInbox.find_or_create_by!(contact_id: contact.id, inbox_id: inbox.id) do |record|
        record.source_id = source_id_for(inbox)
      end
      existing = contact_inbox.conversations.where("additional_attributes ->> 'workflow_test' = 'true'").order(id: :desc).first
      return existing if existing

      inbox.conversations.create!(
        account_id: @account.id,
        contact_id: contact.id,
        contact_inbox_id: contact_inbox.id,
        additional_attributes: { 'workflow_test' => true }
      )
    end

    def sandbox_contact
      email = "workflow-test-#{@workflow.id}@example.com"
      contact = @account.contacts.where('LOWER(email) = ?', email).first
      contact || @account.contacts.create!(
        name: 'Visitante teste',
        email: email,
        additional_attributes: { 'workflow_test' => true }
      )
    end

    def source_id_for(inbox)
      return '+5511900000000' if %w[Channel::Whatsapp Channel::TwilioSms].include?(inbox.channel_type)

      "workflow-test-#{@workflow.id}"
    end

    def reset_sandbox!(conversation)
      conversation.update!(custom_attributes: {})
      conversation.label_list = []
      conversation.save!
      contact = conversation.contact
      contact.update!(
        name: 'Visitante teste',
        custom_attributes: {},
        additional_attributes: contact.additional_attributes.to_h.merge('workflow_test' => true)
      )
      conversation.messages.destroy_all
    end

    def cancel_active!
      @workflow.executions.where("context ->> 'test_mode' = 'true'").where(status: %w[running waiting]).find_each(&:cancel!)
    end

    def create_execution(conversation)
      version = @workflow.current_draft_version
      payload = sample_payload
      @account.workflow_executions.create!(
        workflow: @workflow,
        workflow_version: version,
        contact: conversation.contact,
        conversation: conversation,
        inbox: conversation.inbox,
        trigger_type: @workflow.trigger_type_for(version),
        idempotency_key: "test_#{@workflow.id}_#{SecureRandom.hex(4)}",
        status: 'running',
        started_at: Time.current,
        context: {
          'test_mode' => true,
          'payload' => payload,
          'webhook' => { 'payload' => payload }
        }
      )
    end

    def sample_payload
      trigger = @workflow.webhook_trigger
      payload = trigger.pinned_payload if trigger&.payload_pinned && trigger.pinned_payload.is_a?(Hash)
      payload = trigger.sample_payload if payload.blank? && trigger&.sample_payload.is_a?(Hash)
      payload.is_a?(Hash) ? payload : {}
    end

    def create_incoming!(execution, text, choice_id)
      attributes = {}
      attributes['whatsapp_choice_id'] = choice_id.to_s if choice_id.present?
      execution.conversation.messages.create!(
        account_id: execution.account_id,
        inbox_id: execution.inbox_id,
        message_type: :incoming,
        sender: execution.contact,
        content: text,
        content_attributes: attributes
      )
    end

    def remember_reply!(execution, text)
      wait = pending_wait(execution)
      node = execution.workflow_version.find_node(wait.node_id)
      return unless NodeExecutors::BaseExecutor.node_type_for(node) == 'wait_for_reply'

      wait.update!(metadata: (wait.metadata || {}).merge('reply_content' => text))
    end

    def resume_event(execution, text, choice_id)
      wait = pending_wait(execution)
      node = execution.workflow_version.find_node(wait.node_id)
      type = NodeExecutors::BaseExecutor.node_type_for(node)
      return 'reply_received' unless %w[send_whatsapp_buttons send_whatsapp_list].include?(type)

      choices = Array((wait.metadata || {})['choices'])
      match = choices.find { |choice| choice_id.present? && choice['id'].to_s == choice_id.to_s }
      match ||= choices.find { |choice| text.casecmp?(choice['title'].to_s) }
      match ? match['id'].to_s : 'else'
    end

    def choice_title(execution, choice_id)
      choices = Array((pending_wait(execution).metadata || {})['choices'])
      choices.find { |choice| choice['id'].to_s == choice_id.to_s }&.[]('title').to_s
    end

    def serialize(execution)
      wait = execution.wait_states.pending.order(id: :desc).first
      {
        execution_id: execution.id,
        status: execution.status,
        error: execution.error_message,
        current_node_id: execution.current_node_id,
        waiting_for: waiting_for(execution, wait),
        choices: Array(wait&.metadata&.[]('choices')),
        transcript: transcript(execution)
      }
    end

    def waiting_for(execution, wait)
      return nil unless execution.status == 'waiting' && wait.present?

      Array(wait.metadata&.[]('choices')).present? ? 'choice' : 'reply'
    end

    def transcript(execution)
      entries = execution.conversation.messages.order(:id).map { |message| message_entry(message) }
      entries.concat(execution.node_executions.order(:id).filter_map { |item| step_entry(item) })
      entries.sort_by { |entry| entry[:at].to_s }
    end

    def message_entry(message)
      {
        id: "message-#{message.id}",
        kind: message.incoming? ? 'contact' : 'bot',
        private: message.private?,
        activity: message.activity?,
        content: message.content.to_s,
        items: Array(message.content_attributes&.[]('items')),
        at: message.created_at.iso8601
      }
    end

    def step_entry(item)
      return nil if MESSAGE_NODES.include?(item.node_type)
      return nil if item.node_type.to_s.end_with?('_trigger')

      text = step_text(item)
      return nil if text.blank?

      {
        id: "step-#{item.id}",
        kind: item.status == 'failed' ? 'error' : 'step',
        content: text,
        at: (item.completed_at || item.created_at).iso8601
      }
    end

    def step_text(item)
      output = item.output_data.to_h
      return item.error_message if item.status == 'failed'

      case item.node_type
      when 'delay', 'wait_until'
        'A espera foi pulada neste teste.'
      when 'condition'
        output['matched'] ? 'Condição verdadeira' : 'Condição falsa'
      when 'router'
        "Rota: #{output['selected_route']}"
      when 'set_variable'
        'Variável salva'
      when 'add_tag', 'add_label'
        'Etiqueta adicionada'
      when 'remove_tag', 'remove_label'
        'Etiqueta removida'
      when 'http_request', 'send_webhook'
        'Requisição enviada'
      when 'resolve_conversation'
        'Conversa resolvida'
      when 'reopen_conversation'
        'Conversa reaberta'
      when 'assign_agent'
        'Agente atribuído'
      when 'assign_team'
        'Time atribuído'
      when 'update_contact', 'update_custom_attribute', 'update_conversation'
        'Dados atualizados'
      end
    end
  end
end

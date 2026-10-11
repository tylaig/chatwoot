# frozen_string_literal: true

module Workflows
  class NativeTriggerService
    NODE_TYPES = {
      'message_created' => 'incoming_message_trigger',
      'conversation_created' => 'conversation_created_trigger',
      'webwidget_triggered' => 'widget_opened_trigger',
      'conversation_reopened' => 'conversation_reopened_trigger'
    }.freeze

    def initialize(event_name:, account:, conversation: nil, message: nil, contact_inbox: nil, previous_status: nil)
      @event_name = event_name
      @account = account
      @conversation = conversation
      @message = message
      @contact_inbox = contact_inbox
      @previous_status = previous_status
    end

    def perform
      return if @account.blank?

      Workflow.active.where(account_id: @account.id, trigger_type: @event_name).includes(:active_version).find_each do |workflow|
        start_workflow(workflow)
      end
    end

    private

    def start_workflow(workflow)
      version = workflow.active_version
      return if version.blank?

      node = trigger_node(version)
      return if node.blank?

      config = NodeExecutors::BaseExecutor.config_for(node)
      return unless matches?(workflow, config)

      conversation = conversation_for(workflow, config)
      return if conversation.blank?

      key = idempotency_key(workflow, conversation)
      execution = nil
      workflow.with_lock do
        already_started = WorkflowExecution.exists?(workflow_id: workflow.id, idempotency_key: key)
        execution = create_execution(workflow, version, conversation, key) unless already_started || blocks_parallel_run?(workflow, conversation)
      end
      WorkflowExecutionJob.perform_later(execution.id) if execution
    rescue StandardError => e
      Rails.logger.error("[NativeTriggerService] workflow=#{workflow.id} #{e.class}: #{e.message}")
    end

    def create_execution(workflow, version, conversation, key)
      @account.workflow_executions.create!(
        workflow: workflow,
        workflow_version: version,
        contact: conversation.contact,
        conversation: conversation,
        inbox: conversation.inbox,
        trigger_type: @event_name,
        idempotency_key: key,
        status: 'running',
        started_at: Time.current,
        context: execution_context
      )
    end

    def trigger_node(version)
      expected = NODE_TYPES[@event_name]
      Array(version.nodes).find { |node| NodeExecutors::BaseExecutor.node_type_for(node) == expected }
    end

    def matches?(workflow, config)
      inbox_id = config[:inbox_id].to_i
      return false unless inbox_id.positive? && inbox_id == current_inbox_id

      case @event_name
      when 'message_created'
        message_matches?(config)
      when 'webwidget_triggered'
        widget_matches?(workflow, config)
      when 'conversation_reopened'
        Array(config[:from_statuses]).map(&:to_s).include?(@previous_status.to_s)
      else
        true
      end
    end

    def message_matches?(config)
      return false if @message.blank? || !@message.incoming? || @message.private? || @message.activity?
      return false unless @message.sender_type == 'Contact'

      keyword = config[:keyword].to_s.strip
      if keyword.present? && !@message.content.to_s.downcase.include?(keyword.downcase)
        return false
      end

      config[:occurrence].to_s != 'first' || first_contact_message?
    end

    def first_contact_message?
      first_id = @conversation.messages.where(message_type: :incoming, private: false, sender_type: 'Contact').order(:id).pick(:id)
      first_id == @message.id
    end

    def widget_matches?(workflow, config)
      return false unless @contact_inbox&.inbox&.channel_type == 'Channel::WebWidget'
      return true if config[:frequency].to_s == 'every_open'

      !WorkflowExecution.exists?(workflow_id: workflow.id, idempotency_key: "native_#{workflow.id}_widget_contact_#{@contact_inbox.contact_id}")
    end

    def current_inbox_id
      @conversation&.inbox_id || @contact_inbox&.inbox_id
    end

    def conversation_for(workflow, config)
      return @conversation if @conversation.present?
      return if @contact_inbox.blank?
      return if config[:frequency].to_s != 'every_open' && !widget_matches?(workflow, config)

      active_conversation = @contact_inbox.conversations.where(status: %i[open pending]).order(id: :desc).first
      return active_conversation if active_conversation

      latest = @contact_inbox.conversations.order(id: :desc).first
      return latest if latest && @contact_inbox.inbox.lock_to_single_conversation

      Conversation.create!(
        account_id: @contact_inbox.inbox.account_id,
        inbox_id: @contact_inbox.inbox_id,
        contact_id: @contact_inbox.contact_id,
        contact_inbox_id: @contact_inbox.id
      )
    end

    def blocks_parallel_run?(workflow, conversation)
      return false if stable_once?(@event_name, workflow)

      workflow.executions.exists?(conversation_id: conversation.id, status: %w[running waiting])
    end

    def stable_once?(event_name, workflow)
      return true if event_name == 'conversation_created'
      return true if event_name == 'message_created' && trigger_config(workflow)[:occurrence].to_s == 'first'
      return true if event_name == 'webwidget_triggered' && trigger_config(workflow)[:frequency].to_s != 'every_open'

      false
    end

    def trigger_config(workflow)
      node = trigger_node(workflow.active_version)
      NodeExecutors::BaseExecutor.config_for(node)
    end

    def idempotency_key(workflow, conversation)
      case @event_name
      when 'message_created'
        suffix = trigger_config(workflow)[:occurrence].to_s == 'first' ? "first_#{conversation.id}" : "message_#{@message.id}"
        "native_#{workflow.id}_#{suffix}"
      when 'conversation_created'
        "native_#{workflow.id}_conversation_#{conversation.id}"
      when 'webwidget_triggered'
        if trigger_config(workflow)[:frequency].to_s == 'every_open'
          "native_#{workflow.id}_widget_open_#{@contact_inbox.id}_#{Time.current.to_i}"
        else
          "native_#{workflow.id}_widget_contact_#{@contact_inbox.contact_id}"
        end
      else
        stamp = conversation.status_changed_at&.to_i || conversation.updated_at.to_i
        "native_#{workflow.id}_reopen_#{conversation.id}_#{stamp}"
      end
    end

    def execution_context
      {
        native_trigger: {
          event: @event_name,
          message_id: @message&.id,
          previous_status: @previous_status
        }.compact
      }
    end
  end
end

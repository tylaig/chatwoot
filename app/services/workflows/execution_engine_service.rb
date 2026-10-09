# frozen_string_literal: true

module Workflows
  class ExecutionEngineService
    MAX_STEPS = 50

    def initialize(execution)
      @execution = execution
      @version = execution.workflow_version
      @step_count = 0
    end

    def start!
      return if @execution.status.in?(%w[cancelled paused completed failed])

      trigger_node = @version.trigger_node
      return complete_execution! if trigger_node.blank?

      execute_node(trigger_node)
    end

    def resume!(node_target, event_type = nil)
      from_node_id = node_target.is_a?(Hash) ? (node_target[:node_id] || node_target['node_id']) : node_target
      next_nodes = []

      @execution.with_lock do
        return if @execution.status.in?(%w[cancelled paused completed failed])

        wait_state = @execution.wait_states.pending.lock.find_by(node_id: from_node_id)
        # Prevent race condition: if wait_state is not pending or already resolved, return
        return if wait_state.blank?

        if event_type == 'timeout'
          wait_state.timeout!
          edges = @version.outgoing_edges(from_node_id, 'timeout')
          next_nodes = edges.map { |e| @version.find_node(e['target']) }.compact
          next_nodes = @version.outgoing_edges(from_node_id).map { |e| @version.find_node(e['target']) }.compact if next_nodes.empty?
        else
          wait_state.resume!
          # Follow reply, replied, or default handle
          edges = @version.outgoing_edges(from_node_id, 'reply')
          edges = @version.outgoing_edges(from_node_id, 'replied') if edges.empty?
          next_nodes = edges.map { |e| @version.find_node(e['target']) }.compact
          next_nodes = @version.outgoing_edges(from_node_id).map { |e| @version.find_node(e['target']) }.compact if next_nodes.empty?
        end

        @execution.mark_resumed!
      end

      if next_nodes.present?
        next_nodes.each { |node| execute_node(node) }
      else
        complete_execution!
      end
    end

    private

    def execute_node(node)
      return if @execution.status.in?(%w[cancelled paused])

      @step_count += 1
      if @step_count > MAX_STEPS
        @execution.mark_failed!("Limite máximo de #{MAX_STEPS} passos excedido.")
        return
      end

      @execution.update!(current_node_id: node['id'])

      node_exec = @execution.node_executions.create!(
        node_id: node['id'],
        node_type: node['type'],
        input_data: sanitize_input_data(node['config'] || {}),
        started_at: Time.current,
        status: 'running'
      )

      executor_class = Workflows::NodeRegistry.executor_for(node['type'])
      executor = executor_class.new(execution: @execution, node: node, version: @version)

      result = executor.execute

      case result[:status]
      when 'success'
        node_exec.mark_success!(result[:output] || {})
        next_nodes = result[:next_nodes] || []
        if next_nodes.present?
          next_nodes.each { |nxt| execute_node(nxt) }
        else
          complete_execution!
        end

      when 'waiting'
        node_exec.mark_waiting!(result[:output] || {})
        @execution.mark_waiting!(node['id'])

      when 'failed'
        err_msg = result[:error] || 'Erro desconhecido durante execução do nó.'
        node_exec.mark_failed!(err_msg, result[:output] || {})
        @execution.mark_failed!(err_msg)
      end

    rescue StandardError => e
      Rails.logger.error "[ExecutionEngineService] Error at node #{node['id']}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      node_exec&.mark_failed!(e.message)
      @execution.mark_failed!(e.message)
    end

    def complete_execution!
      @execution.mark_completed! unless @execution.status.in?(%w[failed cancelled])
    end

    def sanitize_input_data(data)
      return data unless data.is_a?(Hash)

      data.each_with_object({}) do |(k, v), acc|
        if k.to_s.downcase.in?(%w[token secret password api_key])
          acc[k] = '[REDACTED]'
        else
          acc[k] = v
        end
      end
    end
  end
end

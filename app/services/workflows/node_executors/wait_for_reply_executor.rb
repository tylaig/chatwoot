# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class WaitForReplyExecutor < BaseExecutor
      def execute
        timeout_hours = (config[:timeout_hours] || config[:timeout] || 24).to_i
        timeout_time = Time.current + timeout_hours.hours

        wait_state = execution.wait_states.create!(
          node_id: node['id'],
          wait_type: 'wait_for_reply',
          timeout_at: timeout_time,
          status: 'pending',
          metadata: {
            timeout_hours: timeout_hours
          }
        )

        # Enqueue timeout check job
        WorkflowExecutionJob.perform_at(timeout_time, execution.id, node['id'], 'timeout')

        {
          status: 'waiting',
          output: {
            waiting_for: 'incoming_message',
            timeout_at: timeout_time,
            wait_state_id: wait_state.id
          },
          next_nodes: []
        }
      end
    end
  end
end

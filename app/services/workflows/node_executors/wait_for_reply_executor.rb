# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class WaitForReplyExecutor < BaseExecutor
      def execute
        timeout_hours = (config[:timeout_hours] || config['timeout_hours'] || config[:timeout] || config['timeout'] || 24).to_i
        timeout_minutes = (config[:timeout_minutes] || config['timeout_minutes']).to_i
        
        timeout_time = if timeout_minutes.positive?
                         Time.current + timeout_minutes.minutes
                       else
                         Time.current + timeout_hours.hours
                       end

        wait_state = execution.wait_states.create!(
          node_id: node['id'],
          wait_type: 'wait_for_reply',
          timeout_at: timeout_time,
          status: 'pending',
          metadata: {
            timeout_hours: timeout_hours,
            timeout_minutes: timeout_minutes
          }
        )

        # Enqueue timeout check job via ActiveJob
        WorkflowExecutionJob.set(wait_until: timeout_time).perform_later(execution.id, node['id'], 'timeout')

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

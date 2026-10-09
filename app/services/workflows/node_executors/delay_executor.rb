# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class DelayExecutor < BaseExecutor
      def execute
        duration_value = (config[:duration] || config[:amount] || 1).to_i
        unit = (config[:unit] || 'minutes').downcase

        delay_duration = case unit
                         when 'seconds', 'second' then duration_value.seconds
                         when 'minutes', 'minute' then duration_value.minutes
                         when 'hours', 'hour' then duration_value.hours
                         when 'days', 'day' then duration_value.days
                         else duration_value.minutes
                         end

        resume_time = Time.current + delay_duration

        # Register wait state
        wait_state = execution.wait_states.create!(
          node_id: node['id'],
          wait_type: 'delay',
          resume_at: resume_time,
          status: 'pending',
          metadata: {
            duration_value: duration_value,
            unit: unit
          }
        )

        # Enqueue background job to resume later
        WorkflowExecutionJob.perform_at(resume_time, execution.id, node['id'])

        {
          status: 'waiting',
          output: {
            delay_duration_seconds: delay_duration.to_i,
            resume_at: resume_time,
            wait_state_id: wait_state.id
          },
          next_nodes: [] # stops synchronous execution chain
        }
      end
    end
  end
end

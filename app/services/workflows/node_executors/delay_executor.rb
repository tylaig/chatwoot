# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class DelayExecutor < BaseExecutor
      def execute
        is_wait_until = (node['type'] == 'wait_until' || config[:until].present? || config['until'].present? || config[:timestamp].present? || config['timestamp'].present?)

        resume_time = if is_wait_until
                        target_str = config[:until] || config['until'] || config[:timestamp] || config['timestamp']
                        Time.zone.parse(target_str.to_s) rescue (Time.current + 1.minute)
                      else
                        duration_value = (config[:delay_amount] || config['delay_amount'] || config[:duration] || config['duration'] || config[:amount] || config['amount'] || 1).to_i
                        unit = (config[:delay_unit] || config['delay_unit'] || config[:unit] || config['unit'] || 'minutes').to_s.downcase

                        delay_duration = case unit
                                         when 'seconds', 'second' then duration_value.seconds
                                         when 'minutes', 'minute' then duration_value.minutes
                                         when 'hours', 'hour' then duration_value.hours
                                         when 'days', 'day' then duration_value.days
                                         else duration_value.minutes
                                         end
                        Time.current + delay_duration
                      end

        # If resume time is already in the past, continue immediately
        if resume_time <= Time.current
          return {
            status: 'success',
            output: { delay_bypassed: true, resume_at: resume_time },
            next_nodes: next_nodes
          }
        end

        # Register wait state
        wait_state = execution.wait_states.create!(
          node_id: node['id'],
          wait_type: is_wait_until ? 'wait_until' : 'delay',
          resume_at: resume_time,
          status: 'pending',
          metadata: {
            is_wait_until: is_wait_until,
            scheduled_for: resume_time
          }
        )

        # Enqueue background job to resume later via ActiveJob
        WorkflowExecutionJob.set(wait_until: resume_time).perform_later(execution.id, node['id'])

        {
          status: 'waiting',
          output: {
            resume_at: resume_time,
            wait_state_id: wait_state.id
          },
          next_nodes: [] # stops synchronous execution chain
        }
      end
    end
  end
end

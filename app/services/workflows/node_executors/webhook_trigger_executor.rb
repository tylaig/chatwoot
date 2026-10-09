# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class WebhookTriggerExecutor < BaseExecutor
      def execute
        # Webhook trigger acts as entry point
        {
          status: 'success',
          output: {
            triggered_at: Time.current,
            payload_keys: execution.context.dig('webhook', 'payload')&.keys || []
          },
          next_nodes: next_nodes
        }
      end
    end
  end
end

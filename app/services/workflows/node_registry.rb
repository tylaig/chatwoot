# frozen_string_literal: true

module Workflows
  class NodeRegistry
    EXECUTOR_MAPPING = {
      'webhook_trigger' => Workflows::NodeExecutors::WebhookTriggerExecutor,
      'send_whatsapp_message' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,
      'send_whatsapp_template' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,
      'send_message' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,
      'condition' => Workflows::NodeExecutors::ConditionExecutor,
      'router' => Workflows::NodeExecutors::RouterExecutor,
      'delay' => Workflows::NodeExecutors::DelayExecutor,
      'wait_until' => Workflows::NodeExecutors::DelayExecutor,
      'wait_for_reply' => Workflows::NodeExecutors::WaitForReplyExecutor,
      'http_request' => Workflows::NodeExecutors::HttpRequestExecutor,
      'send_webhook' => Workflows::NodeExecutors::HttpRequestExecutor,
      'chatwoot_action' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'add_tag' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'remove_tag' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'set_variable' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'resolve_conversation' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'reopen_conversation' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'add_private_note' => Workflows::NodeExecutors::ChatwootActionsExecutor
    }.freeze

    def self.executor_for(node_type)
      clean_type = node_type.to_s.underscore
      EXECUTOR_MAPPING[clean_type] || Workflows::NodeExecutors::BaseExecutor
    end
  end
end

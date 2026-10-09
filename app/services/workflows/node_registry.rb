# frozen_string_literal: true

module Workflows
  class NodeRegistry
    EXECUTOR_MAPPING = {
      # Triggers
      'webhook_trigger' => Workflows::NodeExecutors::WebhookTriggerExecutor,

      # WhatsApp / Mensagens
      'send_whatsapp_message' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,
      'send_whatsapp_template' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,
      'send_message' => Workflows::NodeExecutors::SendWhatsappMessageExecutor,

      # Lógica
      'condition' => Workflows::NodeExecutors::ConditionExecutor,
      'router' => Workflows::NodeExecutors::RouterExecutor,

      # Tempo
      'delay' => Workflows::NodeExecutors::DelayExecutor,
      'wait_until' => Workflows::NodeExecutors::DelayExecutor,
      'wait_for_reply' => Workflows::NodeExecutors::WaitForReplyExecutor,

      # Dados
      'set_variable' => Workflows::NodeExecutors::ChatwootActionsExecutor,

      # CRM / Chatwoot
      'add_tag' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'remove_tag' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'update_contact' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'update_custom_attribute' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'update_conversation' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'assign_agent' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'assign_team' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'add_private_note' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'resolve_conversation' => Workflows::NodeExecutors::ChatwootActionsExecutor,
      'reopen_conversation' => Workflows::NodeExecutors::ChatwootActionsExecutor,

      # Integrações
      'http_request' => Workflows::NodeExecutors::HttpRequestExecutor,
      'send_webhook' => Workflows::NodeExecutors::HttpRequestExecutor,

      # Controle
      'end_workflow' => Workflows::NodeExecutors::ChatwootActionsExecutor
    }.freeze

    def self.executor_for(node_type)
      clean_type = node_type.to_s.underscore
      EXECUTOR_MAPPING[clean_type] || Workflows::NodeExecutors::BaseExecutor
    end

    def self.supported_nodes
      EXECUTOR_MAPPING.keys
    end
  end
end

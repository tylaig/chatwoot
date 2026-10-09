# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class SendWhatsappMessageExecutor < BaseExecutor
      def execute
        conversation = execution.conversation
        if conversation.blank?
          return { status: 'failed', error: 'Conversation não encontrada no contexto de execução.' }
        end

        delivery_mode = config[:delivery_mode] || 'auto' # 'inside_24h', 'outside_24h', 'auto'
        window_service = Workflows::WhatsAppWindowService.new(conversation)
        is_window_open = window_service.open?

        case delivery_mode
        when 'inside_24h'
          unless is_window_open
            if config[:fallback_to_template] && config[:template_name].present?
              return send_template(config[:template_name], config[:template_params])
            end
            return {
              status: 'failed',
              error: 'Janela de 24 horas fechada e mensagem livre bloqueada pela política do WhatsApp.'
            }
          end
          send_freeform_message

        when 'outside_24h'
          template_name = config[:template_name]
          if template_name.blank?
            return { status: 'failed', error: 'Template aprovado obrigatório para envio fora da janela.' }
          end
          send_template(template_name, config[:template_params])

        when 'auto'
          if is_window_open
            send_freeform_message
          else
            template_name = config[:template_name]
            if template_name.present?
              send_template(template_name, config[:template_params])
            else
              {
                status: 'failed',
                error: 'Janela de 24h fechada e nenhum template de fallback configurado para modo automático.'
              }
            end
          end
        else
          send_freeform_message
        end
      end

      private

      def send_freeform_message
        conversation = execution.conversation
        content = resolve_vars(config[:message_content] || config[:text] || '')

        message = conversation.messages.create!(
          account_id: execution.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          status: :sent,
          content: content,
          additional_attributes: {
            workflow_execution_id: execution.id,
            workflow_node_id: node['id']
          }
        )

        dispatch_to_channel(message)

        {
          status: 'success',
          output: {
            message_id: message.id,
            mode: 'freeform',
            content: content
          },
          next_nodes: next_nodes
        }
      end

      def send_template(template_name, template_params_config)
        conversation = execution.conversation
        processed_body = {}

        if template_params_config.is_a?(Array)
          template_params_config.each_with_index do |param, index|
            val = param.is_a?(Hash) ? param['value'] : param
            processed_body[(index + 1).to_s] = resolve_vars(val.to_s)
          end
        elsif template_params_config.is_a?(Hash)
          template_params_config.each do |k, v|
            processed_body[k.to_s] = resolve_vars(v.to_s)
          end
        end

        template_payload = {
          name: template_name,
          category: config[:template_category] || 'UTILITY',
          language: config[:template_language] || 'pt_BR',
          processed_params: {
            body: processed_body
          }
        }

        message = conversation.messages.create!(
          account_id: execution.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          status: :sent,
          content: "Template: #{template_name}",
          additional_attributes: {
            template_params: template_payload,
            workflow_execution_id: execution.id,
            workflow_node_id: node['id']
          }
        )

        dispatch_to_channel(message)

        {
          status: 'success',
          output: {
            message_id: message.id,
            mode: 'template',
            template_name: template_name
          },
          next_nodes: next_nodes
        }
      end

      def dispatch_to_channel(message)
        inbox = message.inbox
        if inbox.channel.is_a?(Channel::Whatsapp)
          Whatsapp::SendOnWhatsappService.new(message: message).perform
        elsif inbox.channel.respond_to?(:send_message)
          inbox.channel.send_message(message)
        end
      end
    end
  end
end

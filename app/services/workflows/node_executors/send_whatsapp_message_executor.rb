# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class SendWhatsappMessageExecutor < BaseExecutor
      def execute
        conversation = execution.conversation
        if conversation.blank?
          return { status: 'failed', error: 'Conversation não encontrada no contexto de execução.' }
        end

        # Guard against duplicate send in case of retries
        existing_msg = find_existing_execution_message(conversation)
        if existing_msg.present?
          mode_str = existing_msg.additional_attributes.dig('template_params').present? ? 'template' : 'free_form'
          return {
            status: 'success',
            output: {
              message_id: existing_msg.id,
              mode: mode_str,
              delivery_method: mode_str,
              note: 'reused_existing_execution_message_for_idempotency'
            },
            next_nodes: next_nodes
          }
        end

        raw_mode = (config[:delivery_mode] || config['delivery_mode'] || config[:mode] || config['mode'] || 'auto').to_s.downcase
        window_service = Workflows::WhatsAppWindowService.new(conversation)
        is_window_open = window_service.open?

        case raw_mode
        when 'inside_24h', 'free_form', 'freeform'
          unless is_window_open
            if (config[:fallback_to_template] || config['fallback_to_template']) && (config[:template_name] || config['template_name']).present?
              return send_template(config[:template_name] || config['template_name'], config[:template_params] || config['template_params'])
            end
            return {
              status: 'failed',
              error: 'Janela de 24 horas fechada e mensagem livre bloqueada pela política do WhatsApp.'
            }
          end
          send_freeform_message

        when 'outside_24h', 'template'
          template_name = config[:template_name] || config['template_name']
          if template_name.blank?
            return { status: 'failed', error: 'Template aprovado obrigatório para envio fora da janela.' }
          end
          send_template(template_name, config[:template_params] || config['template_params'])

        when 'auto', 'automatic'
          if is_window_open
            send_freeform_message
          else
            template_name = config[:template_name] || config['template_name']
            if template_name.present?
              send_template(template_name, config[:template_params] || config['template_params'])
            else
              {
                status: 'failed',
                error: 'Janela de 24h fechada e nenhum template de fallback configurado para modo automático.'
              }
            end
          end
        else
          if is_window_open
            send_freeform_message
          else
            template_name = config[:template_name] || config['template_name']
            template_name.present? ? send_template(template_name, config[:template_params] || config['template_params']) : send_freeform_message
          end
        end
      end

      private

      def find_existing_execution_message(conversation)
        conversation.messages
                    .where(account_id: execution.account_id)
                    .where(message_type: :outgoing)
                    .where("additional_attributes ->> 'workflow_execution_id' = ? AND additional_attributes ->> 'workflow_node_id' = ?", execution.id.to_s, node['id'].to_s)
                    .first
      end

      def send_freeform_message
        conversation = execution.conversation
        content_raw = config[:message_content] || config['message_content'] || config[:content] || config['content'] || config[:text] || config['text'] || ''
        content = resolve_vars(content_raw)

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
            mode: 'free_form',
            delivery_method: 'free_form',
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
            val = param.is_a?(Hash) ? (param['value'] || param[:value]) : param
            processed_body[(index + 1).to_s] = resolve_vars(val.to_s)
          end
        elsif template_params_config.is_a?(Hash)
          template_params_config.each do |k, v|
            val = v.is_a?(Hash) ? (v['value'] || v[:value]) : v
            processed_body[k.to_s] = resolve_vars(val.to_s)
          end
        end

        template_payload = {
          name: template_name,
          category: config[:template_category] || config['template_category'] || 'UTILITY',
          language: config[:template_language] || config['template_language'] || 'pt_BR',
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
            delivery_method: 'template',
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
      rescue StandardError => e
        Rails.logger.warn "[SendWhatsappMessageExecutor] Dispatch to channel warning: #{e.message}"
      end
    end
  end
end

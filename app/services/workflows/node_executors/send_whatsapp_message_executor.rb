# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class SendWhatsappMessageExecutor < BaseExecutor
      def execute
        return preview_template if test_execution? && template_delivery?

        conversation = target_conversation
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

        return send_freeform_message if deliver_without_window?

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

      def target_conversation
        base_conv = execution.conversation
        return nil if base_conv.blank?

        target_inbox_id = (config[:inbox_id] || config['inbox_id']).to_i
        return base_conv if target_inbox_id <= 0 || base_conv.inbox_id == target_inbox_id

        target_inbox = execution.account.inboxes.find_by(id: target_inbox_id)
        return base_conv if target_inbox.blank?

        contact = execution.contact || base_conv.contact
        raw_source = contact.phone_number.presence || contact.email.presence || contact.identifier.presence
        formatted_source = if target_inbox.channel_type == 'Channel::Whatsapp'
                             raw_source.to_s.delete_prefix('whatsapp:').gsub(/\D/, '')
                           else
                             raw_source.to_s
                           end

        contact_inbox = ContactInbox.find_by(contact_id: contact.id, inbox_id: target_inbox.id) ||
                        ContactInbox.find_by(inbox_id: target_inbox.id, source_id: formatted_source) ||
                        ContactInbox.create!(contact_id: contact.id, inbox_id: target_inbox.id, source_id: formatted_source)

        conv = target_inbox.conversations.where(contact_id: contact.id).last
        if conv.blank? || conv.resolved?
          conv = Conversation.create!(
            account_id: execution.account_id,
            inbox_id: target_inbox.id,
            contact_id: contact.id,
            contact_inbox_id: contact_inbox.id,
            status: :open
          )
        end

        execution.update_columns(inbox_id: target_inbox.id, conversation_id: conv.id) # rubocop:disable Rails/SkipsModelValidations
        conv
      end

      def find_existing_execution_message(conversation)
        conversation.messages
                    .where(account_id: execution.account_id)
                    .where(message_type: :outgoing)
                    .where("additional_attributes ->> 'workflow_execution_id' = ? AND additional_attributes ->> 'workflow_node_id' = ?", execution.id.to_s, node['id'].to_s)
                    .first
      end

      def deliver_without_window?
        private_message? || !whatsapp_session_channel?
      end

      def private_message?
        ActiveModel::Type::Boolean.new.cast(config[:private] || config['private'])
      end

      def whatsapp_session_channel?
        target_conversation&.inbox&.channel_type.in?(%w[Channel::Whatsapp Channel::TwilioSms])
      end

      def send_freeform_message
        conversation = target_conversation
        content_raw = config[:message_content] || config['message_content'] || config[:content] || config['content'] || config[:text] || config['text'] || ''
        content = resolve_vars(content_raw)
        files = stored_attachments
        if content.blank? && files.blank?
          return { status: 'failed', error: 'Escreva a mensagem ou anexe um arquivo.' }
        end

        messages = deliver_chatwoot_messages(conversation, content, files)
        {
          status: 'success',
          output: delivery_output(messages, content),
          next_nodes: next_nodes
        }
      rescue ActiveRecord::RecordNotFound
        { status: 'failed', error: 'Um anexo não está mais no armazenamento do Chatwoot.' }
      rescue StandardError => e
        { status: 'failed', error: e.message }
      end

      def send_template(template_name, template_params_config)
        conversation = target_conversation
        processed_body = {}

        if template_params_config.is_a?(Array)
          template_params_config.each_with_index do |param, index|
            val = param.is_a?(Hash) ? (param['value'] || param[:value]) : param
            processed_body[(index + 1).to_s] = resolve_template_param(val.to_s, (index + 1).to_s, template_name, conversation)
          end
        elsif template_params_config.is_a?(Hash)
          template_params_config.each do |k, v|
            val = v.is_a?(Hash) ? (v['value'] || v[:value]) : v
            processed_body[k.to_s] = resolve_template_param(val.to_s, k.to_s, template_name, conversation)
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

      def message_attachments
        Array(config[:attachments] || config['attachments'])
      end

      def stored_attachments
        message_attachments.map do |raw|
          item = raw.is_a?(Hash) ? raw.with_indifferent_access : {}
          blob = ActiveStorage::Blob.find_signed(item[:blob_id].to_s)
          raise ActiveRecord::RecordNotFound if blob.blank?

          item.merge(content_type: blob.content_type, filename: blob.filename.to_s)
        end
      end

      def deliver_chatwoot_messages(conversation, content, files)
        if split_media_delivery? && files.present?
          caption = content
          files.map do |file|
            message = create_chatwoot_message(conversation, caption, [file])
            caption = ''
            message
          end
        else
          [create_chatwoot_message(conversation, content, files)]
        end
      end

      def split_media_delivery?
        return false if private_message?

        channel_type = target_conversation.inbox.channel_type
        return true if %w[Channel::Whatsapp Channel::Instagram Channel::Tiktok].include?(channel_type)

        channel_type == 'Channel::TwilioSms' && target_conversation.inbox.channel.try(:medium) == 'whatsapp'
      end

      def create_chatwoot_message(conversation, content, files)
        voice = files.one? && files.first[:content_type].to_s == 'audio/ogg'
        message = Messages::MessageBuilder.new(
          workflow_sender,
          conversation,
          {
            content: content.presence,
            private: private_message?,
            message_type: 'outgoing',
            attachments: files.map { |file| file[:blob_id] }.presence,
            is_voice_message: voice
          }
        ).perform
        message.update_columns(
          additional_attributes: (message.additional_attributes || {}).merge(
            'workflow_execution_id' => execution.id,
            'workflow_node_id' => node['id'].to_s
          )
        )
        message
      end

      def workflow_sender
        execution.account.administrators.first || execution.account.users.first
      end

      def delivery_output(messages, content)
        attachments = messages.flat_map do |message|
          message.attachments.map do |attachment|
            {
              id: attachment.id,
              message_id: message.id,
              file_type: attachment.file_type,
              filename: attachment.file.filename.to_s
            }
          end
        end
        {
          message_id: messages.first.id,
          message_ids: messages.map(&:id),
          private: messages.first.private?,
          mode: 'free_form',
          delivery_method: 'chatwoot',
          content: content,
          attachments: attachments
        }
      end

      def template_delivery?
        return true if self.class.node_type_for(node) == 'send_whatsapp_template'

        mode = (config[:delivery_mode] || config[:mode] || '').to_s.downcase
        %w[outside_24h template].include?(mode)
      end

      def preview_template
        template_name = config[:template_name] || config['template_name']
        return { status: 'failed', error: 'Selecione um template aprovado.' } if template_name.blank?

        send_template(template_name, config[:template_params] || config['template_params'])
      end

      def resolve_template_param(raw_expr, param_key, template_name, conversation)
        resolved = resolve_vars(raw_expr).to_s.strip
        return resolved if resolved.present?

        fallback = payload_fallback_for_param(param_key, conversation)
        return fallback if fallback.present?

        template_sample_value(template_name, param_key, conversation)
      end

      def payload_fallback_for_param(param_key, conversation)
        pl = (execution.context.to_h['payload'] || execution.context.to_h.dig('webhook', 'payload') || {}).with_indifferent_access
        return '' if pl.blank?

        case param_key.to_s
        when 'primeiro_nome'
          pl.dig(:customer, :first_name).presence || pl.dig(:cliente, :nome)&.to_s&.split&.first.presence || execution.contact&.name&.to_s&.split&.first
        when 'numero_do_pedido', 'numero_pedido'
          pl[:name].presence || (pl[:order_number].present? ? "##{pl[:order_number]}" : nil) || pl.dig(:pedido, :numero)&.to_s
        when 'email'
          pl[:email].presence || pl[:contact_email].presence || pl.dig(:customer, :email).presence || pl.dig(:cliente, :email).presence || execution.contact&.email
        when 'nome_da_loja', 'nome_da_loja2'
          infer_store_name(pl, conversation)
        when 'site_da_loja'
          host = infer_store_host(pl, conversation)
          host.present? ? "https://#{host}" : nil
        when 'link_area_login'
          host = infer_store_host(pl, conversation)
          host.present? ? "https://#{host}/account/login" : pl[:order_status_url].presence
        when 'link_concluir_compra'
          pl[:abandoned_checkout_url].presence || pl[:order_status_url].presence
        else
          nil
        end.to_s.strip
      end

      def infer_store_host(pl, conversation)
        url = pl[:order_status_url].to_s.presence || pl[:abandoned_checkout_url].to_s.presence || pl[:landing_site].to_s.presence
        if url.present? && (uri = URI.parse(url) rescue nil) && uri&.host.present?
          return uri.host
        end

        vendor = Array(pl[:line_items]).first&.dig('vendor').to_s.presence
        return vendor if vendor.present? && vendor.include?('.')

        inbox_name = conversation&.inbox&.name.to_s.downcase
        return 'barbagames.com' if inbox_name.include?('barba')
        return 'gamessafari.com.br' if inbox_name.include?('safari')

        nil
      end

      def infer_store_name(pl, conversation)
        host = infer_store_host(pl, conversation).to_s.downcase
        inbox_name = conversation&.inbox&.name.to_s.downcase
        return 'Barba Games' if host.include?('barba') || inbox_name.include?('barba')
        return 'Games Safari' if host.include?('safari') || inbox_name.include?('safari')
        return 'GameBox Brasil' if host.include?('gamebox') || inbox_name.include?('gamebox')
        return 'Games GL' if host.include?('gamesgl') || inbox_name.include?('games gl')

        conversation&.inbox&.name&.sub(/\s*WhatsApp\z/i, '')&.strip
      end

      def template_sample_value(template_name, param_key, conversation)
        scope = execution.account.whatsapp_templates.where(name: template_name)
        tpl = scope.find_by(inbox_id: conversation&.inbox_id) || scope.first
        return '' if tpl.blank?

        var = Array(tpl.variables).find { |v| v.to_h['key'].to_s == param_key.to_s }
        var.to_h['sample_value'].to_s.strip
      end

      def dispatch_to_channel(message)
        return if test_execution?

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

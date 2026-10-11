# frozen_string_literal: true

module Workflows
  module NodeExecutors
    class SendWhatsappCloudExecutor < BaseExecutor
      MEDIA_TYPES = %w[image video audio document].freeze

      def execute
        return execute_preview if test_execution?

        conversation = execution.conversation
        return failure('Conversa não encontrada no contexto de execução.') if conversation.blank?

        channel = conversation.inbox&.channel
        unless official_cloud?(channel)
          return failure('Este bloco só envia em caixas de entrada com a API oficial do WhatsApp (Cloud API).')
        end
        unless Workflows::WhatsAppWindowService.new(conversation).open?
          return failure('A janela de 24 horas está fechada. Botões, listas e mídias da API oficial só saem dentro dessa janela.')
        end

        existing = find_existing_message(conversation)
        return wait_for_choice if existing.present? && choice_node?

        built = build_session
        return built if built[:status] == 'failed'

        message = conversation.messages.create!(
          account_id: execution.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          status: :sent,
          content: built[:content],
          content_type: built[:content_type],
          content_attributes: built[:content_attributes],
          additional_attributes: {
            workflow_execution_id: execution.id,
            workflow_node_id: node['id'],
            whatsapp_cloud: built[:session]
          }
        )

        phone = conversation.contact_inbox&.source_id.presence || conversation.contact&.phone_number
        return failure('Contato sem telefone para a API oficial.') if phone.blank?

        message_id = channel.provider_service.deliver_session(phone, message, built[:session])
        if message_id.blank?
          return failure(message.reload.external_error.presence || 'A API oficial do WhatsApp recusou a mensagem.')
        end

        message.update!(source_id: message_id) if message.source_id.blank?
        return wait_for_choice if choice_node?

        {
          status: 'success',
          output: { message_id: message.id, source_id: message_id, mode: node_type },
          next_nodes: next_nodes
        }
      end

      private

      def execute_preview
        conversation = execution.conversation
        return failure('Conversa não encontrada no contexto de execução.') if conversation.blank?

        existing = find_existing_message(conversation)
        return wait_for_choice if existing.present? && choice_node?

        built = build_session
        return built if built[:status] == 'failed'

        conversation.messages.create!(
          account_id: execution.account_id,
          inbox_id: conversation.inbox_id,
          message_type: :outgoing,
          status: :sent,
          content: built[:content],
          content_type: built[:content_type],
          content_attributes: built[:content_attributes],
          additional_attributes: {
            workflow_execution_id: execution.id,
            workflow_node_id: node['id'],
            workflow_test: true
          }
        )
        return wait_for_choice if choice_node?

        {
          status: 'success',
          output: { mode: node_type, preview: true },
          next_nodes: next_nodes
        }
      end

      def node_type
        self.class.node_type_for(node)
      end

      def official_cloud?(channel)
        channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'
      end

      def failure(error)
        { status: 'failed', error: error }
      end

      def find_existing_message(conversation)
        conversation.messages
                    .where(account_id: execution.account_id, message_type: :outgoing)
                    .where(
                      "additional_attributes ->> 'workflow_execution_id' = ? AND additional_attributes ->> 'workflow_node_id' = ?",
                      execution.id.to_s,
                      node['id'].to_s
                    )
                    .first
      end

      def build_session
        case node_type
        when 'send_whatsapp_buttons' then build_buttons
        when 'send_whatsapp_list' then build_list
        else build_media
        end
      end

      def choice_node?
        %w[send_whatsapp_buttons send_whatsapp_list].include?(node_type)
      end

      def configured_choices
        list = node_type == 'send_whatsapp_list'
        items = Array(list ? config[:rows] : config[:buttons]).first(list ? 10 : 3)
        prefix = list ? 'item' : 'opcao'
        title_limit = list ? 24 : 20
        id_limit = list ? 200 : 256

        items.filter_map.with_index do |item, index|
          item = item.to_h
          title = resolve_vars(item['title']).to_s.strip
          next if title.blank?

          {
            'id' => (item['id'].presence || "#{prefix}_#{index + 1}").to_s.first(id_limit),
            'title' => title.first(title_limit),
            'description' => resolve_vars(item['description']).to_s.strip.first(72)
          }
        end
      end

      def build_buttons
        body = resolve_vars(config[:body]).to_s.strip
        return failure('O texto da mensagem não pode ficar vazio.') if body.blank?

        choices = configured_choices
        return failure('Informe de 1 a 3 botões.') if choices.empty?

        buttons = choices.map { |choice| { type: 'reply', reply: { id: choice['id'], title: choice['title'] } } }
        interactive = { type: 'button', body: { text: body.first(1024) }, action: { buttons: buttons } }
        apply_header_footer(interactive)
        session_result(body, 'input_select', items_for(buttons), { type: 'interactive', interactive: interactive })
      end

      def build_list
        body = resolve_vars(config[:body]).to_s.strip
        label = resolve_vars(config[:button_label]).to_s.strip
        return failure('O texto da mensagem não pode ficar vazio.') if body.blank?
        return failure('Informe o texto do botão que abre a lista.') if label.blank?

        choices = configured_choices
        return failure('A lista precisa de pelo menos uma opção.') if choices.empty?

        rows = choices.map do |choice|
          item = { id: choice['id'], title: choice['title'] }
          item[:description] = choice['description'] if choice['description'].present?
          item
        end
        interactive = {
          type: 'list',
          body: { text: body.first(1024) },
          action: { button: label.first(20), sections: [{ rows: rows }] }
        }
        apply_header_footer(interactive)
        items = rows.map { |row| { 'title' => row[:title], 'value' => row[:id] } }
        session_result(body, 'input_select', items, { type: 'interactive', interactive: interactive })
      end

      def wait_for_choice
        timeout_time = 24.hours.from_now
        wait_state = execution.wait_states.pending.find_by(node_id: node['id'], wait_type: 'wait_for_reply')
        if wait_state.blank?
          wait_state = execution.wait_states.create!(
            node_id: node['id'],
            wait_type: 'wait_for_reply',
            timeout_at: timeout_time,
            status: 'pending',
            metadata: { choices: configured_choices.map { |choice| choice.slice('id', 'title') } }
          )
          WorkflowExecutionJob.set(wait_until: timeout_time).perform_later(execution.id, node['id'], 'timeout') unless test_execution?
        end

        {
          status: 'waiting',
          output: { waiting_for: 'whatsapp_choice', timeout_at: timeout_time, wait_state_id: wait_state.id },
          next_nodes: []
        }
      end

      def build_media
        kind = config[:media_type].to_s
        return failure('Escolha imagem, vídeo, áudio ou documento.') unless MEDIA_TYPES.include?(kind)

        url = resolve_vars(config[:url]).to_s.strip
        return failure('A mídia precisa de um link https público.') unless url.match?(%r{\Ahttps://})

        media = { link: url }
        caption = resolve_vars(config[:caption]).to_s.strip
        media[:caption] = caption.first(1024) if caption.present? && kind != 'audio'
        media[:filename] = document_filename(url) if kind == 'document'
        session_result(caption.presence || url, 'text', {}, { type: kind, kind => media })
      end

      def apply_header_footer(interactive)
        header = resolve_vars(config[:header]).to_s.strip
        footer = resolve_vars(config[:footer]).to_s.strip
        interactive[:header] = { type: 'text', text: header.first(60) } if header.present?
        interactive[:footer] = { text: footer.first(60) } if footer.present?
      end

      def items_for(buttons)
        buttons.map { |button| { 'title' => button[:reply][:title], 'value' => button[:reply][:id] } }
      end

      def session_result(content, content_type, items, session)
        attributes = items.present? ? { 'items' => items } : {}
        { content: content, content_type: content_type, content_attributes: attributes, session: session }
      end

      def document_filename(url)
        configured = resolve_vars(config[:filename]).to_s.strip
        return configured if configured.present?

        File.basename(URI.parse(url).path.presence || 'arquivo')
      rescue URI::InvalidURIError
        'arquivo'
      end
    end
  end
end

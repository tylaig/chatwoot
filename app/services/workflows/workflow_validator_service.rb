# frozen_string_literal: true

module Workflows
  class WorkflowValidatorService
    VARIABLE_ROOTS = %w[webhook payload trigger contact conversation inbox account vars var workflow custom_attributes].freeze
    VARIABLE_TOKEN = /\{\{(.*?)\}\}/
    VARIABLE_PATH = /\A\$?[a-zA-Z0-9_\-]+(\.[a-zA-Z0-9_\-]+)*\z/
    DECLARED_VAR_PREFIX = /\A(workflow|vars?)\./

    attr_reader :workflow, :version, :issues

    def initialize(workflow, version)
      @workflow = workflow
      @version = version
      @account = workflow.account
      @issues = []
    end

    def errors
      issues.pluck(:message)
    end

    def validate!
      validate_structure!
      return false if issues.any?

      validate_trigger!
      validate_edges!
      validate_connectivity!
      validate_nodes!
      @issues.uniq!
      issues.empty?
    end

    private

    def nodes
      @nodes ||= Array(version.nodes)
    end

    def edges
      @edges ||= Array(version.edges)
    end

    def add_issue(message, node = nil)
      label = node ? node_label(node) : nil
      @issues << { node_id: node&.dig('id'), message: label ? "#{label}: #{message}" : message }
    end

    def node_label(node)
      title = NodeExecutors::BaseExecutor.config_for(node)[:custom_title].presence
      title || NodeExecutors::BaseExecutor.node_type_for(node)
    end

    def node_type(node)
      NodeExecutors::BaseExecutor.node_type_for(node)
    end

    def trigger?(node)
      node_type(node).end_with?('_trigger')
    end

    def validate_structure!
      add_issue('O workflow deve possuir pelo menos um bloco configurado.') if nodes.empty?
    end

    def validate_trigger!
      triggers = nodes.select { |node| trigger?(node) }
      add_issue('O workflow deve possuir um bloco de Gatilho.') if triggers.empty?
      triggers.drop(1).each { |node| add_issue('Apenas um gatilho é permitido por workflow.', node) }
    end

    def validate_edges!
      node_ids = nodes.pluck('id').to_set
      edges.each do |edge|
        next if node_ids.include?(edge['source']) && node_ids.include?(edge['target'])

        add_issue("Conexão inválida entre '#{edge['source']}' e '#{edge['target']}': bloco inexistente.")
      end
    end

    def validate_connectivity!
      targets = edges.pluck('target').to_set
      nodes.each do |node|
        next if trigger?(node) || targets.include?(node['id'])

        add_issue('Bloco não está conectado ao fluxo.', node)
      end
    end

    def validate_nodes!
      nodes.each do |node|
        cfg = NodeExecutors::BaseExecutor.config_for(node)
        validate_node_config(node, cfg)
        validate_variables(node, cfg)
      end
    end

    def validate_node_config(node, cfg)
      case node_type(node)
      when 'send_message'
        has_file = Array(cfg[:attachments]).any? do |item|
          data = item.is_a?(Hash) ? item.with_indifferent_access : {}
          data[:blob_id].present?
        end
        add_issue('Escreva a mensagem ou anexe um arquivo.', node) if cfg[:content].blank? && !has_file
      when 'send_whatsapp_message', 'send_whatsapp_template'
        validate_whatsapp(node, cfg)
      when 'send_whatsapp_buttons', 'send_whatsapp_list', 'send_whatsapp_media'
        validate_official_message(node, cfg)
      when 'condition'
        validate_condition(node, cfg)
      when 'router'
        validate_router(node, cfg)
      when 'http_request', 'send_webhook'
        validate_url(node, cfg[:url].to_s)
      when 'delay'
        add_issue('A duração da espera deve ser um número positivo.', node) unless cfg[:duration].to_i.positive?
      when 'wait_for_reply'
        add_issue('O tempo limite deve ser um número positivo.', node) unless cfg[:timeout_hours].to_i.positive?
        reply_var = cfg[:save_reply_as].to_s.strip
        if reply_var.present? && !reply_var.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          add_issue('Informe um nome de variável válido (letras, números e _).', node)
        end
      when 'set_variable'
        add_issue('Informe um nome de variável válido (letras, números e _).', node) unless cfg[:variable_name].to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
      when 'add_tag', 'remove_tag'
        add_issue('Informe o nome da tag.', node) if cfg[:tag_name].blank?
      when 'update_custom_attribute'
        add_issue('Informe a chave do atributo customizado.', node) if cfg[:attribute_key].blank?
      when 'assign_agent'
        add_issue('Selecione um agente válido.', node) unless @account.users.exists?(id: cfg[:agent_id])
      when 'assign_team'
        add_issue('Selecione um time válido.', node) unless @account.teams.exists?(id: cfg[:team_id])
      when 'incoming_message_trigger', 'conversation_created_trigger', 'widget_opened_trigger', 'conversation_reopened_trigger'
        validate_native_trigger(node, cfg)
      end
    end

    def validate_native_trigger(node, cfg)
      inbox = @account.inboxes.find_by(id: cfg[:inbox_id])
      add_issue('Selecione a caixa de entrada.', node) if inbox.blank?
      if node_type(node) == 'widget_opened_trigger' && inbox && inbox.channel_type != 'Channel::WebWidget'
        add_issue('Este gatilho só funciona em uma caixa de widget.', node)
      end
      if node_type(node) == 'incoming_message_trigger' && !%w[first every].include?(cfg[:occurrence].to_s)
        add_issue('Escolha se o fluxo começa na primeira mensagem ou em cada mensagem.', node)
      end
      if node_type(node) == 'widget_opened_trigger' && !%w[once_per_contact every_open].include?(cfg[:frequency].to_s)
        add_issue('Escolha se o widget inicia o fluxo uma vez ou a cada abertura.', node)
      end
      return unless node_type(node) == 'conversation_reopened_trigger'

      sources = Array(cfg[:from_statuses]).map(&:to_s)
      add_issue('Escolha resolvida, adiada ou as duas.', node) if (sources & %w[resolved snoozed]).empty?
    end

    def validate_whatsapp(node, cfg)
      delivery_mode = cfg[:delivery_mode] || 'auto'
      template_name = cfg[:template_name]

      if node_type(node) == 'send_whatsapp_template' || delivery_mode == 'outside_24h'
        return add_issue('Selecione um template aprovado.', node) if template_name.blank?
      end
      add_issue('A mensagem de texto não pode ficar vazia.', node) if delivery_mode == 'inside_24h' && cfg[:text].blank?
      return if template_name.blank?

      template = @account.whatsapp_templates.find_by(name: template_name)
      if template.blank?
        add_issue("O template '#{template_name}' não foi encontrado na conta.", node)
        return
      elsif template.status != 'APPROVED'
        add_issue("O template '#{template_name}' está com status #{template.status}; apenas templates aprovados podem ser publicados.", node)
      end

      params = cfg[:template_params].is_a?(Hash) ? cfg[:template_params] : {}
      template.body.to_s.scan(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/).flatten.uniq.each do |key|
        add_issue("Preencha a variável {{#{key}}} do template.", node) if params[key].blank?
      end
    end

    def validate_official_message(node, cfg)
      case node_type(node)
      when 'send_whatsapp_buttons'
        add_issue('O texto da mensagem não pode ficar vazio.', node) if cfg[:body].blank?
        buttons = Array(cfg[:buttons])
        add_issue('A API oficial aceita de 1 a 3 botões.', node) unless buttons.size.between?(1, 3)
        buttons.each_with_index do |button, index|
          title = button.to_h['title'].to_s
          add_issue("O botão #{index + 1} precisa de um texto.", node) if title.blank?
          add_issue("O botão #{index + 1} pode ter no máximo 20 caracteres.", node) if plain_over?(title, 20)
        end
      when 'send_whatsapp_list'
        add_issue('O texto da mensagem não pode ficar vazio.', node) if cfg[:body].blank?
        add_issue('Informe o texto do botão que abre a lista.', node) if cfg[:button_label].blank?
        add_issue('O botão da lista pode ter no máximo 20 caracteres.', node) if plain_over?(cfg[:button_label].to_s, 20)
        rows = Array(cfg[:rows])
        add_issue('A lista precisa de 1 a 10 opções.', node) unless rows.size.between?(1, 10)
        rows.each_with_index do |row, index|
          title = row.to_h['title'].to_s
          add_issue("A opção #{index + 1} precisa de um título.", node) if title.blank?
          add_issue("A opção #{index + 1} pode ter no máximo 24 caracteres.", node) if plain_over?(title, 24)
          add_issue("A descrição da opção #{index + 1} pode ter no máximo 72 caracteres.", node) if plain_over?(row.to_h['description'].to_s, 72)
        end
      else
        add_issue('Escolha imagem, vídeo, áudio ou documento.', node) unless %w[image video audio document].include?(cfg[:media_type].to_s)
        url = cfg[:url].to_s
        if url.blank?
          add_issue('Informe o link https da mídia.', node)
        elsif !url.start_with?('https://', '{{')
          add_issue('O link da mídia precisa ser https.', node)
        end
      end
    end

    def plain_over?(text, max)
      text.present? && !text.include?('{{') && text.length > max
    end

    def validate_condition(node, cfg)
      conditions = cfg[:conditions]
      return add_issue('Configure pelo menos uma regra.', node) unless conditions.is_a?(Array) && conditions.any?

      conditions.each_with_index do |condition, index|
        field = condition['field'].to_s
        if field.blank?
          add_issue("Regra ##{index + 1} está sem campo.", node)
        else
          validate_path(node, field)
        end
      end
    end

    def validate_router(node, cfg)
      routes = Array(cfg[:routes])
      add_issue('Configure pelo menos uma rota.', node) if routes.empty?
      names = routes.map { |route| route['name'].to_s.strip }
      add_issue('Todas as rotas precisam de um nome.', node) if names.any?(&:blank?)
      add_issue('Os nomes das rotas precisam ser únicos.', node) if names.uniq.size != names.size
      cfg[:source_variable].present? ? validate_path(node, cfg[:source_variable]) : add_issue('Informe a variável de roteamento.', node)
    end

    def validate_url(node, url)
      if url.blank?
        add_issue('A URL é obrigatória.', node)
      elsif !url.start_with?('http://', 'https://', '{{')
        add_issue('A URL deve iniciar com http:// ou https://.', node)
      end
    end

    def validate_variables(node, cfg)
      collect_strings(cfg.except(:custom_title, :variable_mapping)).each do |text|
        text.scan(VARIABLE_TOKEN).flatten.each do |inner|
          token = inner.strip
          next if token.match?(/\A\d+\z/)

          validate_path(node, token, "{{#{inner}}}")
        end
      end
    end

    def validate_path(node, raw_path, display = raw_path)
      path = VariableResolverService.normalize_path(raw_path)
      return add_issue("Variável com sintaxe inválida: #{display}", node) unless path.match?(VARIABLE_PATH)

      root, name = path.split('.')
      return add_issue("Variável desconhecida: #{display}", node) unless VARIABLE_ROOTS.include?(root)
      return unless %w[vars var].include?(root)

      add_issue("Variável de fluxo não definida: #{display}", node) unless declared_variables.include?(name)
    end

    def declared_variables
      @declared_variables ||= nodes.filter_map do |node|
        cfg = NodeExecutors::BaseExecutor.config_for(node)
        case node_type(node)
        when 'set_variable' then cfg[:variable_name].to_s.delete_prefix('vars.')
        when 'http_request' then (cfg[:save_response_as].presence || 'http_response').to_s.sub(DECLARED_VAR_PREFIX, '')
        end
      end.to_set
    end

    def collect_strings(value)
      case value
      when String then [value]
      when Hash then value.values.flat_map { |item| collect_strings(item) }
      when Array then value.flat_map { |item| collect_strings(item) }
      else []
      end
    end
  end
end

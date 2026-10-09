# frozen_string_literal: true

module Workflows
  class WorkflowValidatorService
    attr_reader :workflow, :version, :errors

    def initialize(workflow, version)
      @workflow = workflow
      @version = version
      @account = workflow.account
      @errors = []
    end

    def validate!
      validate_structure!
      validate_trigger!
      validate_edges!
      validate_nodes!
      errors.empty?
    end

    private

    def validate_structure!
      if version.nodes.blank? || !version.nodes.is_a?(Array) || version.nodes.empty?
        @errors << 'O workflow deve possuir pelo menos um bloco configurado.'
      end
    end

    def validate_trigger!
      return if version.nodes.blank?

      trigger_nodes = version.nodes.select { |n| n['type'].to_s.end_with?('_trigger') || n['type'] == 'webhook_trigger' }
      if trigger_nodes.empty?
        @errors << 'O workflow deve possuir pelo menos um bloco de Gatilho (Trigger).'
      end
    end

    def validate_edges!
      return if version.edges.blank? || version.nodes.blank?

      node_ids = version.nodes.map { |n| n['id'] }.to_set

      version.edges.each do |edge|
        source_id = edge['source']
        target_id = edge['target']

        unless node_ids.include?(source_id)
          @errors << "Conexão inválida: bloco de origem '#{source_id}' não existe no fluxo."
        end

        unless node_ids.include?(target_id)
          @errors << "Conexão inválida: bloco de destino '#{target_id}' não existe no fluxo."
        end
      end
    end

    def validate_nodes!
      return if version.nodes.blank?

      version.nodes.each do |node|
        cfg = (node['config'] || {}).with_indifferent_access
        node_id = node['id']
        node_type = node['type']

        case node_type
        when 'send_whatsapp_message', 'send_whatsapp_template'
          delivery_mode = cfg[:delivery_mode] || 'auto'

          if delivery_mode.in?(%w[outside_24h auto]) && cfg[:template_name].present?
            tpl = @account.whatsapp_templates.find_by(name: cfg[:template_name])
            if tpl.blank?
              @errors << "Bloco #{node_id}: O template WhatsApp '#{cfg[:template_name]}' não foi encontrado na conta."
            elsif tpl.status != 'APPROVED'
              @errors << "Bloco #{node_id}: O template '#{cfg[:template_name]}' possui status '#{tpl.status}'. Apenas templates aprovados (APPROVED) podem ser publicados."
            end
          elsif delivery_mode == 'outside_24h' && cfg[:template_name].blank?
            @errors << "Bloco #{node_id}: Template aprovado é obrigatório para envio fora da janela de 24h."
          end

        when 'condition'
          conditions = cfg[:conditions]
          if conditions.blank? || !conditions.is_a?(Array) || conditions.empty?
            @errors << "Bloco #{node_id} (Condição): Pelo menos uma regra de comparação deve ser configurada."
          else
            conditions.each do |c|
              if c['field'].blank?
                @errors << "Bloco #{node_id} (Condição): O campo da condição não pode estar vazio."
              end
            end
          end

        when 'http_request', 'send_webhook'
          url = cfg[:url].to_s
          if url.blank?
            @errors << "Bloco #{node_id} (HTTP Request): A URL de requisição é obrigatória."
          elsif !url.start_with?('http://', 'https://', '{{')
            @errors << "Bloco #{node_id} (HTTP Request): A URL deve iniciar com http:// ou https://."
          end

        when 'delay'
          duration = cfg[:duration].to_i
          if duration <= 0
            @errors << "Bloco #{node_id} (Delay): A duração da espera deve ser um número positivo."
          end
        end
      end
    end
  end
end

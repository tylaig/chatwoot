# frozen_string_literal: true

class Api::V1::Accounts::WebhookDispatchTriggersController < Api::V1::Accounts::BaseController
  before_action :fetch_trigger, only: [:show, :update, :destroy, :test_payload]

  def index
    triggers = Current.account.webhook_dispatch_triggers.includes(:workflow).order(created_at: :desc)
    recent = recent_dispatches_by_workflow(triggers.filter_map(&:workflow_id).uniq)
    render json: triggers.map { |trigger| serialize_trigger(trigger, recent[trigger.workflow_id]) }
  end

  def show
    render json: @trigger
  end

  def create
    name = trigger_params[:name].to_s.strip
    return render json: { error: ['Informe o nome do webhook.'] }, status: :unprocessable_entity if name.blank?

    inbox = resolve_inbox
    return render json: { error: ['Crie uma caixa de entrada antes de gerar o webhook.'] }, status: :unprocessable_entity if inbox.blank?

    ActiveRecord::Base.transaction do
      workflow = workflow_for(trigger_params[:workflow_id], name)
      raise ActiveRecord::Rollback if performed?

      @trigger = Current.account.webhook_dispatch_triggers.new(name: name, inbox: inbox, workflow: workflow, active: true)
      @trigger.save!
      workflow.ensure_webhook_trigger_node!
    end
    return if performed?

    render json: serialize_trigger(@trigger), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    workflow_id = trigger_params[:workflow_id]
    if workflow_id.present? && workflow_id.to_i != @trigger.workflow_id
      workflow = workflow_for(workflow_id, @trigger.name)
      return if performed?

      @trigger.workflow = workflow
      workflow.ensure_webhook_trigger_node!
    end

    mapping = trigger_params[:field_mapping]
    if mapping.present?
      @trigger.field_mapping = @trigger.field_mapping.to_h.merge(mapping.to_h)
    end
    pin_sample_payload!

    if @trigger.update(trigger_params.except(:workflow_id, :field_mapping))
      render json: serialize_trigger(@trigger)
    else
      render json: { error: @trigger.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @trigger.destroy!
    head :no_content
  end

  def test_payload
    payload = parsed_test_payload
    return if payload == :invalid

    if ActiveModel::Type::Boolean.new.cast(params[:save])
      suggest_mapping_paths!(payload)
      @trigger.update!(
        sample_payload: payload,
        sample_received_at: Time.current,
        pinned_payload: payload,
        payload_pinned: true
      )
    end

    body = mapping_preview(payload).merge(trigger: serialize_trigger(@trigger))
    return render json: body unless ActiveModel::Type::Boolean.new.cast(params[:execute])

    result = @trigger.run_test_execution(payload)
    if result[:success]
      render json: body.merge(result).merge(trigger: serialize_trigger(@trigger))
    else
      render json: body.merge(error: result[:error]), status: :unprocessable_entity
    end
  end

  private

  def fetch_trigger
    @trigger = Current.account.webhook_dispatch_triggers.find(params[:id])
  end

  def serialize_trigger(trigger, executions = nil)
    rows = executions || recent_dispatches_by_workflow([trigger.workflow_id])[trigger.workflow_id]
    trigger.as_json.merge(
      workflow: trigger.workflow&.as_json(only: [:id, :name, :status]),
      recent_dispatches: Array(rows).map do |execution|
        {
          id: execution.id,
          status: execution.status,
          created_at: execution.created_at,
          error_message: execution.error_message
        }
      end
    )
  end

  def recent_dispatches_by_workflow(workflow_ids)
    workflow_ids.compact.index_with do |workflow_id|
      WorkflowExecution.where(workflow_id: workflow_id).order(created_at: :desc).limit(3).to_a
    end
  end

  def trigger_params
    params.require(:webhook_dispatch_trigger).permit(
      :inbox_id,
      :workflow_id,
      :name,
      :active,
      :payload_pinned,
      :template_name,
      :template_language,
      field_mapping: [:phone_path, :name_path, { custom_attributes: [:attribute_key, :source_path] }],
      sample_payload: {}
    )
  end

  def parsed_test_payload
    raw = params[:payload]
    data = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw
    data = JSON.parse(data) if data.is_a?(String)
    unless data.is_a?(Hash)
      render json: { error: 'Cole um objeto JSON, como { "customer": { "phone": "5511999990000" } }.' }, status: :unprocessable_entity
      return :invalid
    end
    if data.to_json.bytesize > 100_000
      render json: { error: 'O JSON passa de 100 KB.' }, status: :unprocessable_entity
      return :invalid
    end

    data
  rescue JSON::ParserError
    render json: { error: 'Esse texto não é um JSON válido.' }, status: :unprocessable_entity
    :invalid
  end

  def mapping_preview(payload)
    mapping = @trigger.field_mapping.to_h
    phone_path = mapping['phone_path'].presence || 'customer.phone'
    name_path = mapping['name_path'].presence || 'customer.name'
    phone = @trigger.extract_by_path(payload, phone_path)
    resolved_parameters = Array(mapping['parameters']).map do |param|
      param.to_h['type'] == 'static' ? param.to_h['value'] : @trigger.extract_by_path(payload, param.to_h['value'])
    end
    attributes = Array(mapping['custom_attributes']).filter_map do |row|
      source = row.to_h['source_path'].presence
      key = row.to_h['attribute_key'].presence
      next if source.blank? && key.blank?

      { attribute_key: key, source_path: source, value: @trigger.extract_by_path(payload, source) }
    end

    {
      phone: phone,
      phone_path: phone_path,
      name: @trigger.extract_by_path(payload, name_path),
      name_path: name_path,
      template_name: @trigger.template_name,
      resolved_parameters: resolved_parameters,
      attributes: attributes,
      valid: phone.present?
    }
  end

  def suggest_mapping_paths!(payload)
    mapping = @trigger.field_mapping.to_h
    paths = payload_leaf_paths(payload)
    mapping['phone_path'] = mapping['phone_path'].presence || paths.find { |path| phone_key?(path) }
    mapping['name_path'] = mapping['name_path'].presence || paths.find { |path| name_key?(path) }
    @trigger.field_mapping = mapping
  end

  def phone_key?(path)
    path.split('.').last.match?(/phone|telefone|celular|whatsapp|mobile/i)
  end

  def name_key?(path)
    path.split('.').last.match?(/\A(name|full_name|nome|nome_completo)\z/i)
  end

  def payload_leaf_paths(value, prefix = nil)
    return [] unless value.is_a?(Hash)

    value.flat_map do |key, child|
      path = prefix ? "#{prefix}.#{key}" : key.to_s
      child.is_a?(Hash) ? payload_leaf_paths(child, path) : [path]
    end
  end

  def pin_sample_payload!
    return unless trigger_params.key?(:payload_pinned)
    return unless ActiveModel::Type::Boolean.new.cast(trigger_params[:payload_pinned])
    return if @trigger.pinned_payload.present? || @trigger.sample_payload.blank?

    @trigger.pinned_payload = @trigger.sample_payload
  end

  def resolve_inbox
    inbox_id = trigger_params[:inbox_id]
    if inbox_id.present?
      Current.account.inboxes.find_by(id: inbox_id)
    else
      Current.account.inboxes.order(:id).first
    end
  end

  def workflow_for(workflow_id, name)
    if workflow_id.present?
      workflow = Current.account.workflows.find_by(id: workflow_id)
      unless workflow
        render json: { error: ['Fluxo não encontrado.'] }, status: :unprocessable_entity
        return
      end
      existing = workflow.webhook_trigger
      if existing && existing.id != @trigger&.id
        render json: { error: ['Este fluxo já tem um webhook.'] }, status: :unprocessable_entity
        return
      end
      workflow
    else
      workflow = Current.account.workflows.create!(
        name: name,
        description: 'Criado a partir da aba Webhooks',
        status: 'draft',
        trigger_type: 'webhook',
        created_by: current_user
      )
      workflow.current_draft_version
      workflow
    end
  end
end

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

  # Dry-run test endpoint: tests the JSON mapping against a payload without sending real WhatsApp message
  def test_payload
    payload = params[:payload].presence || {}

    phone = @trigger.extract_by_path(payload, @trigger.field_mapping['phone_path'])
    name = @trigger.extract_by_path(payload, @trigger.field_mapping['name_path'])
    
    mapping_params = @trigger.field_mapping['parameters'] || []
    resolved_params = mapping_params.map do |param|
      if param['type'] == 'static'
        param['value']
      else
        @trigger.extract_by_path(payload, param['value'])
      end
    end

    render json: {
      phone: phone,
      name: name,
      template_name: @trigger.template_name,
      resolved_parameters: resolved_params,
      valid: phone.present?
    }
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
      :template_name,
      :template_language,
      field_mapping: [:phone_path, :name_path, { custom_attributes: [:attribute_key, :source_path] }],
      sample_payload: {}
    )
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

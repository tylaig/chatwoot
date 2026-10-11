# frozen_string_literal: true

class Api::V1::Accounts::WorkflowsController < Api::V1::Accounts::BaseController
  EDGE_KEYS = %w[id source target sourceHandle targetHandle type animated style label].freeze
  NODE_KEYS = %w[id type position data config].freeze

  before_action :fetch_workflow, only: [:show, :update, :destroy, :publish, :pause, :activate, :duplicate, :executions,
                                        :webhook_trigger, :upsert_webhook_trigger, :test_webhook_trigger]
  before_action :check_authorization
  before_action :validate_draft_version_params, only: [:update]

  def index
    @workflows = Current.account.workflows.where.not(status: 'archived').order(updated_at: :desc)
    @workflows = @workflows.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

    scope = Current.account.workflows
    stats = {
      total: scope.where.not(status: 'archived').count,
      active: scope.active.count,
      drafts: scope.drafts.count,
      paused: scope.paused.count
    }

    render json: {
      workflows: @workflows.as_json(
        include: {
          active_version: { only: [:id, :version_number, :status] },
          created_by: { only: [:id, :name] }
        },
        methods: [:execution_stats, :webhook_path]
      ),
      stats: stats
    }
  end

  def show
    draft_version = @workflow.current_draft_version
    render json: @workflow.as_json(
      include: {
        active_version: { only: [:id, :version_number, :nodes, :edges, :viewport, :status, :created_at] },
        versions: { only: [:id, :version_number, :status, :created_at, :change_summary] }
      }
    ).merge(
      draft_version: draft_version.as_json(only: [:id, :version_number, :nodes, :edges, :viewport, :status, :updated_at]),
      has_unpublished_changes: @workflow.unpublished_changes?,
      webhook_trigger: serialize_webhook_trigger(@workflow.webhook_trigger)
    )
  end

  def create
    @workflow = Current.account.workflows.new(workflow_params)
    @workflow.created_by = current_user

    if @workflow.save
      draft = @workflow.current_draft_version
      render json: @workflow.as_json.merge(draft_version: draft), status: :created
    else
      render json: { error: @workflow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @workflow.update!(workflow_params) if params[:workflow].present?
      update_draft! if params[:draft_version].present?
    end

    render json: @workflow.as_json.merge(has_unpublished_changes: @workflow.unpublished_changes?)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @workflow.archive!
    head :no_content
  end

  def publish
    validator = Workflows::WorkflowValidatorService.new(@workflow, @workflow.current_draft_version)
    unless validator.validate!
      return render json: { error: validator.errors, issues: validator.issues }, status: :unprocessable_entity
    end

    version = @workflow.publish!(params[:summary])
    render json: { success: true, active_version_id: version.id, version_number: version.version_number, status: @workflow.status }
  end

  def pause
    @workflow.pause!
    render json: { success: true, status: @workflow.status }
  end

  def activate
    return render json: { error: ['Publique o workflow antes de ativá-lo.'] }, status: :unprocessable_entity if @workflow.active_version.blank?

    @workflow.activate!
    render json: { success: true, status: @workflow.status }
  end

  def duplicate
    dup_wf = Current.account.workflows.create!(
      name: "#{@workflow.name} (Cópia)",
      description: @workflow.description,
      status: 'draft',
      trigger_type: @workflow.trigger_type,
      created_by: current_user
    )

    src_version = @workflow.versions.drafts.first || @workflow.active_version
    dup_wf.current_draft_version.update!(
      nodes: src_version.nodes,
      edges: src_version.edges,
      viewport: src_version.viewport
    )

    render json: dup_wf, status: :created
  end

  def test_http
    config = params.require(:config).permit(
      :method, :url, :body, :timeout, :retry_count, :retry_interval,
      :auth_type, :auth_token, :save_response_as,
      headers: [:key, :value],
      params: [:key, :value]
    ).to_h
    result = Workflows::NodeExecutors::HttpRequestExecutor.probe(config)
    render json: result, status: result[:ok] ? :ok : :unprocessable_entity
  end

  def executions
    execs = @workflow.executions.order(created_at: :desc).limit(50)
    render json: execs.as_json(
      include: {
        contact: { only: [:id, :name, :phone_number] },
        conversation: { only: [:id, :display_id, :status] }
      }
    )
  end

  def webhook_trigger
    render json: { webhook_trigger: serialize_webhook_trigger(@workflow.webhook_trigger) }
  end

  def test_webhook_trigger
    trigger = @workflow.webhook_trigger
    return render json: { error: ['Gere a URL do webhook antes de testar.'] }, status: :unprocessable_entity if trigger.blank?

    result = trigger.run_test_execution
    if result[:success]
      render json: {
        execution_id: result[:workflow_execution_id],
        conversation_id: result[:conversation_id],
        contact_id: result[:contact_id]
      }
    else
      render json: { error: [result[:error]] }, status: :unprocessable_entity
    end
  end

  def upsert_webhook_trigger
    attrs = webhook_trigger_params
    inbox = attrs[:inbox_id].present? ? Current.account.inboxes.find_by(id: attrs[:inbox_id]) : nil
    return render json: { error: ['Caixa de entrada inválida.'] }, status: :unprocessable_entity if attrs[:inbox_id].present? && inbox.blank?

    trigger = @workflow.webhook_trigger || Current.account.webhook_dispatch_triggers.new(workflow: @workflow, name: "Workflow: #{@workflow.name}")
    trigger.inbox = inbox || trigger.inbox || Current.account.inboxes.order(:id).first
    return render json: { error: ['Crie uma caixa de entrada antes de gerar o webhook.'] }, status: :unprocessable_entity if trigger.inbox.blank?

    trigger.field_mapping = trigger.field_mapping.to_h.merge(attrs[:field_mapping].to_h) if attrs.key?(:field_mapping)
    pasted = pasted_sample_payload
    return if pasted == :invalid

    if pasted.is_a?(Hash)
      trigger.sample_payload = pasted
      trigger.sample_received_at = Time.current
      trigger.pinned_payload = pasted
      trigger.payload_pinned = true
    end
    if attrs.key?(:payload_pinned) && !pasted.is_a?(Hash)
      trigger.payload_pinned = ActiveModel::Type::Boolean.new.cast(attrs[:payload_pinned])
      trigger.pinned_payload = trigger.sample_payload if trigger.payload_pinned && trigger.sample_payload.present?
    end
    trigger.save!
    render json: { webhook_trigger: serialize_webhook_trigger(trigger) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def fetch_workflow
    @workflow = Current.account.workflows.find(params[:id])
  end

  def workflow_params
    params.require(:workflow).permit(:name, :description, :trigger_type, :status)
  end

  def webhook_trigger_params
    params.permit(:inbox_id, :payload_pinned, field_mapping: [:phone_path, :name_path, { custom_attributes: [:attribute_key, :source_path] }])
  end

  def pasted_sample_payload
    return nil unless params.key?(:sample_payload)

    raw = params[:sample_payload]
    data = raw.is_a?(ActionController::Parameters) ? raw.to_unsafe_h : raw
    unless data.is_a?(Hash)
      render json: { error: ['Cole um objeto JSON, como { "customer": { "phone": "5511999990000" } }.'] }, status: :unprocessable_entity
      return :invalid
    end
    if data.to_json.bytesize > 100_000
      render json: { error: ['O JSON passa de 100 KB.'] }, status: :unprocessable_entity
      return :invalid
    end

    data
  end

  def validate_draft_version_params
    draft = params[:draft_version]
    return if draft.blank?

    nodes = draft[:nodes]
    edges = draft[:edges]
    valid = (nodes.nil? || nodes.is_a?(Array)) && (edges.nil? || edges.is_a?(Array))
    valid &&= Array(nodes).all? { |node| node.respond_to?(:key?) && node[:id].present? }
    valid &&= Array(edges).all? { |edge| edge.respond_to?(:key?) && edge[:source].present? && edge[:target].present? }
    return if valid

    render json: { error: ['Estrutura do fluxo inválida: blocos precisam de id e conexões de origem/destino.'] }, status: :unprocessable_entity
  end

  def update_draft!
    draft = @workflow.current_draft_version
    draft_params = params[:draft_version]
    draft.update!(
      nodes: draft_params.key?(:nodes) ? sanitize_list(draft_params[:nodes], NODE_KEYS) : draft.nodes,
      edges: draft_params.key?(:edges) ? sanitize_list(draft_params[:edges], EDGE_KEYS) : draft.edges,
      viewport: draft_params[:viewport].present? ? draft_params[:viewport].permit(:x, :y, :zoom).to_h : draft.viewport
    )
  end

  def sanitize_list(list, keys)
    Array(list).map { |item| item.to_unsafe_h.slice(*keys) }
  end

  def serialize_webhook_trigger(trigger)
    return if trigger.blank?

    {
      id: trigger.id,
      name: trigger.name,
      token: trigger.token,
      path: "/webhooks/trigger/#{trigger.token}",
      inbox_id: trigger.inbox_id,
      active: trigger.active,
      field_mapping: trigger.field_mapping,
      sample_payload: trigger.sample_payload,
      pinned_payload: trigger.pinned_payload,
      payload_pinned: trigger.payload_pinned,
      received_at: trigger.sample_received_at
    }
  end
end

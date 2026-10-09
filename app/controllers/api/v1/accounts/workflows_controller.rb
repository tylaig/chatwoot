# frozen_string_literal: true

class Api::V1::Accounts::WorkflowsController < Api::V1::Accounts::BaseController
  before_action :fetch_workflow, only: [:show, :update, :destroy, :publish, :pause, :activate, :duplicate, :executions]

  def index
    @workflows = Current.account.workflows.order(updated_at: :desc)
    
    # Filter by status if provided
    @workflows = @workflows.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

    stats = {
      total: Current.account.workflows.count,
      active: Current.account.workflows.active.count,
      drafts: Current.account.workflows.drafts.count,
      paused: Current.account.workflows.paused.count
    }

    render json: {
      workflows: @workflows.as_json(
        include: {
          active_version: { only: [:id, :version_number, :nodes, :edges, :status] }
        },
        methods: [:execution_stats]
      ),
      stats: stats
    }
  end

  def show
    draft_version = @workflow.current_draft_version
    render json: @workflow.as_json(
      include: {
        active_version: { only: [:id, :version_number, :nodes, :edges, :viewport, :status] },
        versions: { only: [:id, :version_number, :status, :created_at] }
      }
    ).merge(
      draft_version: draft_version.as_json(only: [:id, :version_number, :nodes, :edges, :viewport, :status])
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
    if @workflow.update(workflow_params)
      # If version nodes/edges were passed, update draft version
      if params[:draft_version].present?
        draft = @workflow.current_draft_version
        draft.update!(
          nodes: params[:draft_version][:nodes] || draft.nodes,
          edges: params[:draft_version][:edges] || draft.edges,
          viewport: params[:draft_version][:viewport] || draft.viewport
        )
      end

      render json: @workflow
    else
      render json: { error: @workflow.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @workflow.archive!
    head :no_content
  end

  def publish
    draft = @workflow.publish!(params[:summary])
    render json: { success: true, active_version_id: draft.id, status: @workflow.status }
  end

  def pause
    @workflow.pause!
    render json: { success: true, status: @workflow.status }
  end

  def activate
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

    src_version = @workflow.active_version || @workflow.current_draft_version
    dup_wf.current_draft_version.update!(
      nodes: src_version.nodes,
      edges: src_version.edges,
      viewport: src_version.viewport
    )

    render json: dup_wf, status: :created
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

  private

  def fetch_workflow
    @workflow = Current.account.workflows.find(params[:id])
  end

  def workflow_params
    params.require(:workflow).permit(:name, :description, :trigger_type, :status)
  end
end

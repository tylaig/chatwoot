# frozen_string_literal: true

class Api::V1::Accounts::WorkflowExecutionsController < Api::V1::Accounts::BaseController
  before_action :fetch_execution, only: [:show, :cancel, :retry_node]

  def index
    @executions = Current.account.workflow_executions.order(created_at: :desc)
    @executions = @executions.where(workflow_id: params[:workflow_id]) if params[:workflow_id].present?
    @executions = @executions.where(status: params[:status]) if params[:status].present? && params[:status] != 'all'

    render json: @executions.limit(50).as_json(
      include: {
        workflow: { only: [:id, :name] },
        contact: { only: [:id, :name, :phone_number] },
        conversation: { only: [:id, :display_id, :status] }
      }
    )
  end

  def show
    render json: @execution.as_json(
      include: {
        workflow: { only: [:id, :name] },
        workflow_version: { only: [:id, :version_number, :nodes, :edges] },
        contact: { only: [:id, :name, :phone_number] },
        conversation: { only: [:id, :display_id, :status] },
        node_executions: {
          only: [:id, :node_id, :node_type, :status, :input_data, :output_data, :error_message, :duration_ms, :started_at, :completed_at]
        },
        wait_states: {
          only: [:id, :node_id, :wait_type, :status, :resume_at, :timeout_at]
        }
      }
    )
  end

  def cancel
    @execution.cancel!
    render json: { success: true, status: @execution.status }
  end

  private

  def fetch_execution
    @execution = Current.account.workflow_executions.find(params[:id])
  end
end

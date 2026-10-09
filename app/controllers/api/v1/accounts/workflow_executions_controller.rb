# frozen_string_literal: true

class Api::V1::Accounts::WorkflowExecutionsController < Api::V1::Accounts::BaseController
  before_action :fetch_execution, only: [:show, :retry_execution, :cancel]
  before_action :check_authorization

  def index
    @executions = Current.account.workflow_executions.order(created_at: :desc)
    @executions = @executions.where(workflow_id: params[:workflow_id]) if params[:workflow_id].present?
    @executions = @executions.where(status: params[:status]) if params[:status].present?

    @executions = @executions.page(params[:page] || 1).per(25)

    render json: {
      executions: @executions.as_json(
        include: {
          workflow: { only: [:id, :name] },
          contact: { only: [:id, :name, :phone_number] },
          conversation: { only: [:id, :display_id, :status] }
        }
      ),
      meta: {
        current_page: @executions.current_page,
        total_pages: @executions.total_pages,
        total_count: @executions.total_count
      }
    }
  end

  def show
    render json: @execution.as_json(
      include: {
        workflow: { only: [:id, :name, :status] },
        workflow_version: { only: [:id, :version_number, :nodes, :edges, :viewport] },
        node_executions: {
          only: [:id, :node_id, :node_type, :status, :started_at, :finished_at, :completed_at, :duration_ms, :input_data, :output_data, :error_message]
        },
        wait_states: {
          only: [:id, :node_id, :wait_type, :status, :resume_at, :timeout_at, :resumed_at]
        },
        contact: { only: [:id, :name, :phone_number, :email] },
        conversation: { only: [:id, :display_id, :status] }
      }
    )
  end

  def retry_execution
    if @execution.status.in?(%w[failed cancelled])
      @execution.update!(status: 'running', error_message: nil)
      WorkflowExecutionJob.perform_later(@execution.id, @execution.current_node_id)
      render json: { success: true, message: 'Execução reenfileirada com sucesso.' }
    else
      render json: { error: 'Apenas execuções com falha ou canceladas podem ser reiniciadas.' }, status: :unprocessable_entity
    end
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

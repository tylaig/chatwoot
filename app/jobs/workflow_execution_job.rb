# frozen_string_literal: true

class WorkflowExecutionJob < ApplicationJob
  queue_as :default

  def perform(execution_id, resume_node_id = nil, event_type = nil)
    execution = WorkflowExecution.find_by(id: execution_id)
    return if execution.blank? || execution.status == 'cancelled'

    engine = Workflows::ExecutionEngineService.new(execution)

    if resume_node_id.present?
      engine.resume!(resume_node_id, event_type)
    else
      engine.start!
    end
  rescue StandardError => e
    execution&.mark_failed!(e.message) if execution&.status == 'running'
    Rails.logger.error("[WorkflowExecutionJob] execution=#{execution_id} #{e.class}: #{e.message}")
  end
end

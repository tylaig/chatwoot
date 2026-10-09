# frozen_string_literal: true

class WorkflowNodeExecution < ApplicationRecord
  belongs_to :workflow_execution

  STATUSES = %w[running success failed skipped waiting].freeze

  validates :node_id, presence: true
  validates :node_type, presence: true
  validates :status, inclusion: { in: STATUSES }

  def mark_success!(output = {})
    update!(
      status: 'success',
      output_data: output,
      completed_at: Time.current,
      duration_ms: calculate_duration
    )
  end

  def mark_failed!(error, output = {})
    update!(
      status: 'failed',
      error_message: error,
      output_data: output,
      completed_at: Time.current,
      duration_ms: calculate_duration
    )
  end

  def mark_waiting!(output = {})
    update!(
      status: 'waiting',
      output_data: output,
      completed_at: Time.current,
      duration_ms: calculate_duration
    )
  end

  private

  def calculate_duration
    return 0 if started_at.blank?
    ((Time.current - started_at) * 1000).to_i
  end
end

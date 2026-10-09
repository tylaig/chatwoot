# frozen_string_literal: true

class WorkflowExecution < ApplicationRecord
  belongs_to :account
  belongs_to :workflow
  belongs_to :workflow_version
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  has_many :node_executions, class_name: 'WorkflowNodeExecution', dependent: :destroy
  has_many :wait_states, class_name: 'WorkflowWaitState', dependent: :destroy
  has_one :wait_state, -> { order(created_at: :desc) }, class_name: 'WorkflowWaitState'

  STATUSES = %w[running waiting completed failed cancelled paused].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :running, -> { where(status: 'running') }
  scope :waiting, -> { where(status: 'waiting') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  def mark_completed!
    update!(status: 'completed', finished_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: 'failed', finished_at: Time.current, error_message: message)
  end

  def mark_waiting!(node_id)
    update!(status: 'waiting', current_node_id: node_id)
  end

  def mark_resumed!
    update!(status: 'running')
  end

  def cancel!
    update!(status: 'cancelled', finished_at: Time.current)
    wait_states.where(status: 'pending').update_all(status: 'cancelled')
  end
end

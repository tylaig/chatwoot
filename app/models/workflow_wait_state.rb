# frozen_string_literal: true

class WorkflowWaitState < ApplicationRecord
  belongs_to :workflow_execution

  STATUSES = %w[pending resumed timed_out cancelled].freeze
  WAIT_TYPES = %w[delay wait_for_reply wait_until].freeze

  validates :node_id, presence: true
  validates :wait_type, inclusion: { in: WAIT_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: 'pending') }
  scope :due_for_resume, -> { pending.where('resume_at <= ?', Time.current) }
  scope :timed_out, -> { pending.where('timeout_at <= ?', Time.current) }

  def resume!
    update!(status: 'resumed')
  end

  def timeout!
    update!(status: 'timed_out')
  end

  def cancel!
    update!(status: 'cancelled')
  end
end

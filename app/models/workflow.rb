# frozen_string_literal: true

class Workflow < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :active_version, class_name: 'WorkflowVersion', optional: true

  has_many :versions, class_name: 'WorkflowVersion', dependent: :destroy
  has_many :executions, class_name: 'WorkflowExecution', dependent: :destroy_async

  STATUSES = %w[draft active paused archived].freeze
  TRIGGER_TYPES = %w[webhook conversation_created message_created contact_created].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }

  scope :active, -> { where(status: 'active') }
  scope :drafts, -> { where(status: 'draft') }
  scope :paused, -> { where(status: 'paused') }
  scope :archived, -> { where(status: 'archived') }

  def execution_stats
    {
      total: executions.count,
      completed: executions.completed.count,
      failed: executions.failed.count,
      running: executions.running.count,
      waiting: executions.waiting.count
    }
  end

  def current_draft_version
    versions.find_or_create_by!(status: 'draft') do |v|
      v.version_number = (versions.maximum(:version_number) || 0) + 1
      v.nodes = default_initial_nodes
      v.edges = []
    end
  end

  def publish!(summary = nil)
    transaction do
      draft = current_draft_version
      draft.update!(status: 'published', change_summary: summary)
      update!(status: 'active', active_version_id: draft.id)
      draft
    end
  end

  def pause!
    update!(status: 'paused')
  end

  def activate!
    update!(status: 'active')
  end

  def archive!
    update!(status: 'archived')
  end

  private

  def default_initial_nodes
    [
      {
        id: 'node_trigger',
        type: 'webhook_trigger',
        position: { x: 250, y: 100 },
        config: {
          title: 'Webhook Trigger',
          description: 'Inicia a automação a partir de um webhook ou evento externo'
        }
      }
    ]
  end
end

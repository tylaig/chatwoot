# frozen_string_literal: true

class Workflow < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :active_version, class_name: 'WorkflowVersion', optional: true

  has_many :versions, class_name: 'WorkflowVersion', dependent: :destroy
  has_many :executions, class_name: 'WorkflowExecution', dependent: :destroy_async

  STATUSES = %w[draft active paused archived].freeze
  TRIGGER_TYPES = %w[webhook conversation_created message_created contact_created webwidget_triggered conversation_reopened].freeze
  NATIVE_TRIGGER_TYPES = {
    'webhook_trigger' => 'webhook',
    'incoming_message_trigger' => 'message_created',
    'conversation_created_trigger' => 'conversation_created',
    'widget_opened_trigger' => 'webwidget_triggered',
    'conversation_reopened_trigger' => 'conversation_reopened'
  }.freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }

  scope :active, -> { where(status: 'active') }
  scope :drafts, -> { where(status: 'draft') }
  scope :paused, -> { where(status: 'paused') }
  scope :archived, -> { where(status: 'archived') }

  def execution_stats
    grouped = executions.group(:status).count
    completed = grouped['completed'].to_i
    failed = grouped['failed'].to_i
    finished = completed + failed
    duration = executions.where.not(started_at: nil).where.not(finished_at: nil)
                         .average('EXTRACT(EPOCH FROM (finished_at - started_at))')

    {
      total: grouped.values.sum,
      completed: completed,
      failed: failed,
      running: grouped['running'].to_i,
      waiting: grouped['waiting'].to_i,
      success_rate: finished.positive? ? ((completed * 100.0) / finished).round : 0,
      avg_duration_seconds: duration&.to_f&.round
    }
  end

  def webhook_trigger
    WebhookDispatchTrigger.where(account_id: account_id, workflow_id: id).order(updated_at: :desc).first
  end

  def webhook_path
    token = webhook_trigger&.token
    return if token.blank?

    "/webhooks/trigger/#{token}"
  end

  def current_draft_version
    versions.find_or_create_by!(status: 'draft') do |v|
      v.version_number = (versions.maximum(:version_number) || 0) + 1
      v.nodes = active_version&.nodes.presence || default_initial_nodes
      v.edges = active_version&.edges || []
      v.viewport = active_version.viewport if active_version
    end
  end

  def unpublished_changes?
    return true if active_version.blank?

    draft = versions.drafts.first
    return false if draft.blank?

    draft.nodes != active_version.nodes || draft.edges != active_version.edges
  end

  def publish!(summary = nil)
    transaction do
      draft = current_draft_version
      draft.update!(status: 'published', change_summary: summary)
      update!(status: 'active', active_version_id: draft.id, trigger_type: trigger_type_for(draft))
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

  def ensure_webhook_trigger_node!
    draft = current_draft_version
    nodes = Array(draft.nodes).map(&:deep_dup)
    has_webhook = nodes.any? { |node| [node['type'], node.dig('data', 'type')].include?('webhook_trigger') }
    update!(trigger_type: 'webhook') unless trigger_type == 'webhook'
    return if has_webhook

    nodes.unshift(
      'id' => "node_#{SecureRandom.hex(4)}",
      'type' => 'webhook_trigger',
      'position' => { 'x' => 80, 'y' => 160 },
      'data' => { 'type' => 'webhook_trigger', 'config' => {} },
      'config' => {}
    )
    draft.update!(nodes: nodes)
  end

  def trigger_type_for(version)
    node = Array(version.nodes).find do |item|
      type = item['type'].to_s
      type = item.dig('data', 'type').to_s if type.blank? || type == 'custom'
      type.end_with?('_trigger')
    end
    type = node&.dig('data', 'type').presence || node&.[]('type').to_s
    NATIVE_TRIGGER_TYPES[type] || trigger_type
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

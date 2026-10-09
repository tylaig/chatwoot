# frozen_string_literal: true

class WorkflowVersion < ApplicationRecord
  belongs_to :workflow
  has_many :executions, class_name: 'WorkflowExecution', dependent: :nullify

  validates :version_number, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  scope :published, -> { where(status: 'published') }
  scope :drafts, -> { where(status: 'draft') }

  def find_node(node_id)
    nodes.find { |n| n['id'] == node_id }
  end

  def outgoing_edges(node_id, handle = nil)
    edges.select do |e|
      match_source = e['source'] == node_id
      handle.present? ? (match_source && (e['sourceHandle'] == handle || e['sourceHandle'].blank?)) : match_source
    end
  end

  def trigger_node
    nodes.find { |n| n['type']&.include?('trigger') } || nodes.first
  end
end

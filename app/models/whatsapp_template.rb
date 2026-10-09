# frozen_string_literal: true

class WhatsappTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true

  CATEGORIES = %w[MARKETING_LITE MARKETING UTILITY AUTHENTICATION].freeze
  STATUSES = %w[APPROVED PENDING REJECTED DRAFT PAUSED].freeze
  HEADER_TYPES = %w[NONE TEXT IMAGE VIDEO DOCUMENT].freeze

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: 'permite apenas letras minúsculas, números e underlines' }
  validates :category, inclusion: { in: CATEGORIES }
  validates :language, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :body, presence: true, length: { maximum: 1024 }
  validates :footer, length: { maximum: 60 }, allow_blank: true

  scope :approved, -> { where(status: 'APPROVED') }
  scope :pending, -> { where(status: 'PENDING') }
  scope :rejected, -> { where(status: 'REJECTED') }

  def approve!
    update!(status: 'APPROVED', rejection_reason: nil)
  end

  def submit_review!
    update!(status: 'PENDING', rejection_reason: nil)
  end

  def reject!(reason = nil)
    update!(status: 'REJECTED', rejection_reason: reason)
  end
end

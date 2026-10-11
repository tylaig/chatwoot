# frozen_string_literal: true

class WhatsappTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  has_one_attached :header_media

  CATEGORIES = %w[MARKETING_LITE MARKETING UTILITY AUTHENTICATION].freeze
  STATUSES = %w[APPROVED PENDING REJECTED DRAFT PAUSED].freeze
  HEADER_TYPES = %w[NONE TEXT IMAGE VIDEO DOCUMENT].freeze
  HEADER_MEDIA_TYPES = {
    'IMAGE' => %w[image/jpeg image/png],
    'VIDEO' => %w[video/mp4],
    'DOCUMENT' => %w[application/pdf]
  }.freeze

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: 'permite apenas letras minúsculas, números e underlines' }
  validates :category, inclusion: { in: CATEGORIES }
  validates :language, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :body, presence: true, length: { maximum: 1024 }
  validates :footer, length: { maximum: 60 }, allow_blank: true
  validate :header_media_matches_type

  before_save :detach_header_media_when_unused

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

  def as_json(options = {})
    super.merge(
      'header_media_name' => (header_media.filename.to_s if header_media.attached?)
    )
  end

  private

  def header_media_matches_type
    return unless header_media.attached?
    return unless HEADER_MEDIA_TYPES.key?(header_type)

    allowed = HEADER_MEDIA_TYPES[header_type]
    return if allowed.include?(header_media.blob&.content_type)

    errors.add(:header_media, 'use JPEG ou PNG para imagem, MP4 para vídeo e PDF para documento')
  end

  def detach_header_media_when_unused
    return if HEADER_MEDIA_TYPES.key?(header_type)

    header_media.detach if header_media.attached?
  end
end

# frozen_string_literal: true

class AppointmentType < ApplicationRecord
  LOCATION_TYPES = %w[google_meet in_person phone whatsapp custom].freeze

  belongs_to :account
  belongs_to :calendar_schedule, optional: true
  has_many :calendar_appointments, dependent: :nullify

  before_validation :normalize_slug

  validates :title, presence: true
  validates :slug, presence: true
  validates :duration_minutes, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 480 }
  validates :buffer_minutes, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 240 }
  validates :location_type, inclusion: { in: LOCATION_TYPES }

  scope :active, -> { where(active: true) }

  def as_api_json
    {
      id: id,
      account_id: account_id,
      calendar_schedule_id: calendar_schedule_id,
      title: title,
      slug: slug,
      description: description,
      duration_minutes: duration_minutes,
      buffer_minutes: buffer_minutes,
      location_type: location_type,
      location_details: location_details,
      color: color,
      active: active,
      price_cents: price_cents,
      currency: currency,
      custom_questions: custom_questions || []
    }
  end

  private

  def normalize_slug
    base = (slug.presence || title.to_s).parameterize
    base = "servico-#{SecureRandom.hex(3)}" if base.blank?
    self.slug = base
  end
end

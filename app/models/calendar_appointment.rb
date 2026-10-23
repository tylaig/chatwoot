# frozen_string_literal: true

class CalendarAppointment < ApplicationRecord
  STATUSES = %w[confirmed pending cancelled rescheduled completed no_show].freeze
  SOURCES = %w[operator ai_agent public_link google_sync].freeze

  belongs_to :account
  belongs_to :calendar_schedule
  belongs_to :appointment_type, optional: true
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true

  before_validation :ensure_uid, on: :create

  validates :uid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :customer_name, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validate :validate_time_order

  scope :active_bookings, -> { where(status: %w[confirmed pending]) }
  scope :upcoming, -> { active_bookings.where('ends_at >= ?', Time.current).order(starts_at: :asc) }

  def duration_minutes
    ((ends_at - starts_at) / 60.0).round
  end

  def as_api_json
    tz = ActiveSupport::TimeZone[timezone.presence || calendar_schedule&.timezone || 'America/Sao_Paulo'] || Time.zone
    local_start = starts_at.in_time_zone(tz)
    local_end = ends_at.in_time_zone(tz)

    {
      id: id,
      uid: uid,
      account_id: account_id,
      calendar_schedule_id: calendar_schedule_id,
      professional_name: calendar_schedule&.name,
      professional_slug: calendar_schedule&.slug,
      professional_color: calendar_schedule&.color,
      professional_role: calendar_schedule&.role_title,
      appointment_type_id: appointment_type_id,
      appointment_type_title: appointment_type&.title,
      contact_id: contact_id,
      conversation_id: conversation_id,
      conversation_display_id: conversation&.display_id,
      title: title,
      notes: notes,
      customer_name: customer_name,
      customer_email: customer_email,
      customer_phone: customer_phone,
      starts_at: local_start.iso8601,
      ends_at: local_end.iso8601,
      date: local_start.strftime('%Y-%m-%d'),
      start_time: local_start.strftime('%H:%M'),
      end_time: local_end.strftime('%H:%M'),
      duration_minutes: duration_minutes,
      timezone: tz.tzinfo.name,
      status: status,
      source: source,
      location_type: location_type,
      meeting_url: meeting_url,
      google_event_id: google_event_id,
      google_synced: google_event_id.present?,
      reminder_24h_sent: reminder_24h_sent,
      reminder_1h_sent: reminder_1h_sent,
      metadata: metadata || {},
      created_at: created_at&.iso8601
    }
  end

  private

  def ensure_uid
    self.uid ||= "msc-#{SecureRandom.alphanumeric(10).downcase}"
  end

  def validate_time_order
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, 'deve ser posterior ao horário de início') if ends_at <= starts_at
  end
end

# frozen_string_literal: true

class CalendarSchedule < ApplicationRecord
  DEFAULT_WEEKLY_HOURS = {
    '1' => [{ 'start' => '09:00', 'end' => '12:00' }, { 'start' => '14:00', 'end' => '18:30' }],
    '2' => [{ 'start' => '09:00', 'end' => '12:00' }, { 'start' => '14:00', 'end' => '18:30' }],
    '3' => [{ 'start' => '09:00', 'end' => '12:00' }, { 'start' => '14:00', 'end' => '18:30' }],
    '4' => [{ 'start' => '09:00', 'end' => '12:00' }, { 'start' => '14:00', 'end' => '18:30' }],
    '5' => [{ 'start' => '09:00', 'end' => '12:00' }, { 'start' => '14:00', 'end' => '17:30' }],
    '6' => [],
    '0' => []
  }.freeze

  belongs_to :account
  belongs_to :user, optional: true
  has_many :appointment_types, dependent: :destroy
  has_many :calendar_appointments, dependent: :destroy

  before_validation :normalize_slug
  before_validation :ensure_default_weekly_hours, on: :create

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :account_id }
  validates :slot_duration_minutes, numericality: { greater_than_or_equal_to: 10, less_than_or_equal_to: 480 }
  validates :buffer_before_minutes, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 240 }
  validates :buffer_after_minutes, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 240 }
  validates :minimum_notice_minutes, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10_080 }
  validates :max_days_ahead, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 365 }

  scope :active, -> { where(active: true) }
  scope :ai_bookable, -> { active.where(ai_bookable: true) }

  def effective_weekly_hours
    weekly_hours.presence || DEFAULT_WEEKLY_HOURS
  end

  def public_booking_url
    base = ENV.fetch('FRONTEND_URL', 'https://chat.meusuper.app').sub(%r{/+$}, '')
    "#{base}/agendar/#{slug}"
  end

  def team_booking_slug
    settings['team_slug'].presence || account.name.to_s.parameterize.presence || "conta-#{account_id}"
  end

  def as_api_json(today_count: nil)
    {
      id: id,
      account_id: account_id,
      user_id: user_id,
      name: name,
      slug: slug,
      role_title: role_title,
      bio: bio,
      avatar_url: avatar_url.presence || user&.avatar_url,
      color: color,
      timezone: timezone,
      active: active,
      ai_bookable: ai_bookable,
      google_email: google_email,
      google_calendar_id: google_calendar_id,
      google_connected: google_connected,
      weekly_hours: effective_weekly_hours,
      slot_duration_minutes: slot_duration_minutes,
      buffer_before_minutes: buffer_before_minutes,
      buffer_after_minutes: buffer_after_minutes,
      minimum_notice_minutes: minimum_notice_minutes,
      max_days_ahead: max_days_ahead,
      settings: settings || {},
      public_booking_url: public_booking_url,
      today_appointments_count: today_count || calendar_appointments.where(
        status: 'confirmed',
        starts_at: Time.current.in_time_zone(timezone).all_day
      ).count,
      appointment_types: appointment_types.select(&:active).map(&:as_api_json)
    }
  end

  private

  def normalize_slug
    base = (slug.presence || name.to_s).parameterize
    base = "agenda-#{SecureRandom.hex(3)}" if base.blank?
    candidate = base
    counter = 2
    while self.class.where(account_id: account_id).where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end
    self.slug = candidate
  end

  def ensure_default_weekly_hours
    self.weekly_hours = DEFAULT_WEEKLY_HOURS.deep_dup if weekly_hours.blank?
  end
end

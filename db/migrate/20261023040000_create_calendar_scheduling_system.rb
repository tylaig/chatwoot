class CreateCalendarSchedulingSystem < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_schedules, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, null: true, foreign_key: true, index: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :role_title
      t.text :bio
      t.string :avatar_url
      t.string :color, default: '#10b981', null: false
      t.string :timezone, default: 'America/Sao_Paulo', null: false
      t.boolean :active, default: true, null: false
      t.boolean :ai_bookable, default: true, null: false
      t.string :google_email
      t.string :google_calendar_id, default: 'primary'
      t.boolean :google_connected, default: false, null: false
      t.jsonb :google_credentials, default: {}, null: false
      t.jsonb :weekly_hours, default: {}, null: false
      t.integer :slot_duration_minutes, default: 30, null: false
      t.integer :buffer_before_minutes, default: 0, null: false
      t.integer :buffer_after_minutes, default: 15, null: false
      t.integer :minimum_notice_minutes, default: 60, null: false
      t.integer :max_days_ahead, default: 30, null: false
      t.jsonb :settings, default: {}, null: false
      t.timestamps
    end

    add_index :calendar_schedules, [:account_id, :slug], unique: true, if_not_exists: true
    add_index :calendar_schedules, :slug, if_not_exists: true

    create_table :appointment_types, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :calendar_schedule, null: true, foreign_key: true, index: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :duration_minutes, default: 30, null: false
      t.integer :buffer_minutes, default: 15, null: false
      t.string :location_type, default: 'google_meet', null: false
      t.string :location_details
      t.string :color, default: '#10b981', null: false
      t.boolean :active, default: true, null: false
      t.integer :price_cents, default: 0, null: false
      t.string :currency, default: 'BRL', null: false
      t.jsonb :custom_questions, default: [], null: false
      t.timestamps
    end

    add_index :appointment_types, [:account_id, :slug], if_not_exists: true

    create_table :calendar_appointments, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :calendar_schedule, null: false, foreign_key: true, index: true
      t.references :appointment_type, null: true, foreign_key: true, index: true
      t.references :contact, null: true, foreign_key: true, index: true
      t.references :conversation, null: true, foreign_key: true, index: true
      t.string :uid, null: false
      t.string :title, null: false
      t.text :notes
      t.string :customer_name, null: false
      t.string :customer_email
      t.string :customer_phone
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, default: 'America/Sao_Paulo', null: false
      t.string :status, default: 'confirmed', null: false
      t.string :source, default: 'operator', null: false
      t.string :location_type, default: 'google_meet', null: false
      t.string :meeting_url
      t.string :google_event_id
      t.string :google_calendar_id
      t.boolean :reminder_24h_sent, default: false, null: false
      t.boolean :reminder_1h_sent, default: false, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :calendar_appointments, :uid, unique: true, if_not_exists: true
    add_index :calendar_appointments, [:calendar_schedule_id, :starts_at, :ends_at], name: 'idx_cal_appointments_schedule_window', if_not_exists: true
    add_index :calendar_appointments, [:account_id, :starts_at], if_not_exists: true
  end
end

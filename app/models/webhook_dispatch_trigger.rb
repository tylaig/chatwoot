# frozen_string_literal: true

class WebhookDispatchTrigger < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  validates :name, presence: true
  validates :template_name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(active: true) }

  def execute_payload(payload)
    parsed_phone = extract_by_path(payload, field_mapping['phone_path'])
    parsed_name = extract_by_path(payload, field_mapping['name_path'])

    return { error: 'Phone number not found in payload mapping' } if parsed_phone.blank?

    template_params = build_template_parameters(payload)

    Whatsapp::WebhookTriggerDispatchService.new(
      trigger: self,
      phone_number: parsed_phone.to_s,
      contact_name: parsed_name.to_s.presence || 'Cliente',
      template_params: template_params,
      labels: field_mapping['labels'] || []
    ).perform
  end

  def extract_by_path(data, path)
    return nil if data.blank? || path.blank?

    keys = path.to_s.split('.')
    current = data.with_indifferent_access

    keys.each do |key|
      return nil unless current.is_a?(Hash) || current.is_a?(Array)

      current = if current.is_a?(Array) && key.match?(/^\d+$/)
                  current[key.to_i]
                elsif current.is_a?(Hash)
                  current[key]
                else
                  nil
                end
    end
    current
  end

  private

  def generate_token
    self.token ||= "whk_#{SecureRandom.hex(16)}"
  end

  def build_template_parameters(payload)
    mapping_params = field_mapping['parameters'] || []
    processed_params = []

    mapping_params.each do |param|
      value = if param['type'] == 'static'
                param['value']
              else
                extract_by_path(payload, param['value'])
              end
      processed_params << (value || '')
    end

    {
      name: template_name,
      category: 'UTILITY',
      language: template_language.presence || 'pt_BR',
      processed_params: processed_params
    }
  end
end

# frozen_string_literal: true

class Whatsapp::TemplateStatusService
  STATUS_MAP = Whatsapp::ImportTemplatesService::STATUS_MAP.merge(
    'REINSTATED' => 'APPROVED',
    'FLAGGED' => 'PENDING'
  ).freeze

  def initialize(phone_number:, payload:)
    @phone_number = phone_number
    @payload = payload.to_h.with_indifferent_access
  end

  def perform
    Array(@payload[:entry]).each do |entry|
      Array(entry[:changes]).each do |change|
        next unless change[:field] == 'message_template_status_update'

        apply(entry[:id], change[:value] || {})
      end
    end
  end

  private

  def apply(waba_id, value)
    status = STATUS_MAP[value[:event].to_s]
    return if status.blank?

    record = find_template(waba_id, value)
    return unless record

    reason = value[:reason].to_s
    reason = nil if reason.blank? || reason == 'NONE'
    record.update!(status: status, rejection_reason: reason&.truncate(255, omission: ''))
  end

  def find_template(waba_id, value)
    scope = WhatsappTemplate.where(account_id: account_ids(waba_id))
    return if scope.none?

    template_id = value[:message_template_id].to_s
    record = scope.find_by(meta_template_id: template_id) if template_id.present?
    return record if record

    name = value[:message_template_name].to_s
    language = value[:message_template_language].to_s
    return if name.blank?

    scope.find_by(name: name, language: language.presence || 'pt_BR')
  end

  def account_ids(waba_id)
    ids = []
    if @phone_number.present?
      channel = Channel::Whatsapp.find_by(phone_number: @phone_number)
      ids << channel.account_id if channel
    end
    if waba_id.present?
      ids.concat(
        Channel::Whatsapp.where("provider_config ->> 'business_account_id' = ?", waba_id.to_s).pluck(:account_id)
      )
    end
    ids.uniq
  end
end

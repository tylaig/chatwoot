# Resolves the WhatsApp channel for an inbound WhatsApp Cloud webhook. Meta's
# display_phone_number can arrive formatted or in a country-specific variant (e.g. Brazil
# omits the mobile 9, Argentina adds a digit after the country code), so we try the
# raw digits first and then a normalized fallback, accepting only a candidate whose
# phone_number_id matches.
class Whatsapp::WebhookChannelFinderService
  def initialize(display_phone_number:, phone_number_id:)
    @display_phone_number = display_phone_number
    @phone_number_id = phone_number_id
  end

  def perform
    return if digits.blank?

    channels = [
      *active_channels("+#{digits}"),
      *active_channels_for_normalized_number
    ]
    channels.uniq(&:id).find { |channel| channel.provider_config['phone_number_id'] == @phone_number_id }
  end

  private

  def digits
    @digits ||= @display_phone_number.to_s.gsub(/[^0-9]/, '')
  end

  def active_channels(number)
    Channel::Whatsapp.joins(:inbox).where(phone_number: number, inboxes: { legacy: false }).order(updated_at: :desc)
  end

  def active_channels_for_normalized_number
    normalizer = Whatsapp::PhoneNumberNormalizationService::NORMALIZERS
                 .lazy.map(&:new).find { |n| n.handles_country?(digits) }
    return [] unless normalizer

    active_channels("+#{normalizer.normalize(digits)}")
  end
end

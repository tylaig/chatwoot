# Stops a legacy WhatsApp Cloud inbox from owning the Meta callback.
# Never deregisters the phone number or unsubscribes the WABA: a newer inbox
# on the same number still needs both.
class Whatsapp::LegacyWebhookService
  def initialize(channel)
    @channel = channel
  end

  def perform(legacy:)
    return unless cloud_channel?
    return if active_sibling?

    if legacy
      Whatsapp::FacebookApiClient.new(api_key).clear_phone_number_callback_override(phone_number_id)
    else
      @channel.perform_webhook_setup
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Legacy webhook sync failed for channel #{@channel.id}: #{e.message}"
  end

  private

  def cloud_channel?
    @channel.provider == 'whatsapp_cloud' && api_key.present? && phone_number_id.present?
  end

  def api_key
    provider_config['api_key'].to_s
  end

  def phone_number_id
    provider_config['phone_number_id'].to_s
  end

  def provider_config
    @channel.provider_config || {}
  end

  def active_sibling?
    Channel::Whatsapp
      .joins(:inbox)
      .where.not(id: @channel.id)
      .where(inboxes: { legacy: false })
      .exists?(["provider_config ->> 'phone_number_id' = ?", phone_number_id])
  end
end

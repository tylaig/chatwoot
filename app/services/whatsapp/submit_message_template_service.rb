# frozen_string_literal: true

class Whatsapp::SubmitMessageTemplateService
  def initialize(template)
    @template = template
  end

  def perform
    channel = cloud_channel
    unless channel
      return {
        success: false,
        error: 'Nenhuma inbox WhatsApp Cloud está conectada. Salve o template para usar no fluxo, ou conecte o número da Meta para enviar à revisão.'
      }
    end

    response = HTTParty.post(
      "#{api_base}/#{api_version}/#{channel.provider_config['business_account_id']}/message_templates",
      headers: {
        'Authorization' => "Bearer #{channel.provider_config['api_key']}",
        'Content-Type' => 'application/json'
      },
      body: Whatsapp::MetaTemplateBuilder.new(@template).graph_payload.to_json
    )

    if response.success?
      { success: true, template_id: response['id'], status: response['status'].presence || 'PENDING' }
    else
      message = response.parsed_response.is_a?(Hash) ? response.parsed_response.dig('error', 'message') : nil
      { success: false, error: message.presence || 'A Meta recusou o template.' }
    end
  rescue StandardError => e
    Rails.logger.error "WhatsApp template submit failed: #{e.message}"
    { success: false, error: 'Não foi possível enviar o template para a Meta.' }
  end

  private

  def cloud_channel
    candidates = []
    candidates << @template.inbox&.channel
    candidates.concat(@template.account.inboxes.includes(:channel).map(&:channel))
    candidates.compact.find { |channel| cloud?(channel) }
  end

  def cloud?(channel)
    channel.is_a?(Channel::Whatsapp) &&
      channel.provider == 'whatsapp_cloud' &&
      channel.provider_config['business_account_id'].present? &&
      channel.provider_config['api_key'].present?
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def api_base
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end

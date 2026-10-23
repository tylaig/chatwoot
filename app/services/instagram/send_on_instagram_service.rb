class Instagram::SendOnInstagramService < Instagram::BaseSendService
  include Instagram::RequestOptions

  private

  def channel_class
    Channel::Instagram
  end

  # Deliver a message with the given payload.
  # https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/messaging-api
  def send_message(message_content)
    response = post_instagram_message(message_content)

    # Fallback anti-508 (Invalid message id) on Instagram Direct when URLs/link previews or reply_to fail
    if instagram_508_error?(response) && message_content.dig(:message, :text).present?
      sanitized_payload = sanitize_payload_for_508_retry(message_content)
      if sanitized_payload != message_content
        Rails.logger.warn("[Instagram::SendOnInstagramService] Retrying 508 error with sanitized URL text for message_id=#{message.id}")
        response = post_instagram_message(sanitized_payload)
      end
    end

    process_response(response, message_content)
  end

  def post_instagram_message(payload)
    access_token = channel.access_token
    query = { access_token: access_token }
    instagram_id = channel.instagram_id.presence || 'me'

    HTTParty.post(
      "https://graph.instagram.com/#{GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')}/#{instagram_id}/messages",
      body: payload,
      query: query,
      **INSTAGRAM_REQUEST_OPTIONS
    )
  end

  def instagram_508_error?(response)
    parsed = response&.parsed_response
    return false unless parsed.is_a?(Hash)

    error_code = parsed.dig('error', 'code').to_i
    error_subcode = parsed.dig('error', 'error_subcode').to_i
    error_msg = parsed.dig('error', 'message').to_s

    error_code == 508 || error_subcode == 508 || error_msg.include?('Invalid message id')
  end

  def sanitize_payload_for_508_retry(payload)
    dup_payload = payload.deep_dup
    dup_payload[:message]&.delete(:reply_to)
    text = dup_payload.dig(:message, :text).to_s
    # Neutralize bare URLs/domains so Instagram Graph API does not fail link-preview generation with 508
    sanitized_text = text.gsub(%r{https?://}i, '')
                         .gsub(/\b([a-z0-9-]+)\.(com|br|net|org|io|app)\b/i, '\1 . \2')
    dup_payload[:message][:text] = sanitized_text
    dup_payload
  end

  def merge_human_agent_tag(params)
    global_config = GlobalConfig.get('ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT')

    return params unless global_config['ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT'] && human_agent_tag_applicable?

    params[:messaging_type] = 'MESSAGE_TAG'
    params[:tag] = 'HUMAN_AGENT'
    params
  end
end

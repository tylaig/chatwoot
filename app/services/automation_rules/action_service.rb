class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    # The activity messages the actions trigger are rendered as each change commits, in the thread's
    # locale. A rule runs in Sidekiq, where that is the locale of whoever enqueued the event (English
    # for an inbound message) or the process default, so the account's is named here. No
    # InvalidLocale guard: `locale` is an enum over LANGUAGES_CONFIG, all of it loaded.
    I18n.with_locale(@account.locale) do
      # Taken once, before the first action: the text of every action of this run reads the same
      # picture, and reads it even after the actions that erase what it shows already ran.
      Current.conversation_snapshot = ConversationSnapshot.new(@conversation)

      @rule.actions.each do |action|
        @conversation.reload
        action = action.with_indifferent_access
        begin
          send(action[:action_name], action[:action_params])
        rescue StandardError => e
          ChatwootExceptionTracker.new(e, account: @account).capture_exception
        end
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?
    return if skip_whatsapp_cloud_auto_reply?

    content_text, cta_url = parse_message_and_cta_url(message)
    content_attrs = { automation_rule_id: @rule.id }
    content_attrs[:cta_url] = cta_url if cta_url.present?

    params = { content: content_text, private: false, content_attributes: content_attrs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def skip_whatsapp_cloud_auto_reply?
    channel = @conversation.inbox&.channel
    return false unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'

    return true if channel.service_limit_reached?

    cooldown_hours = (channel.provider_config['auto_reply_cooldown_hours'].presence || 24).to_i
    return false unless cooldown_hours.positive?

    @conversation.messages.outgoing
                 .where("content_attributes->>'automation_rule_id' = ?", @rule.id.to_s)
                 .where('created_at >= ?', cooldown_hours.hours.ago)
                 .where.not(status: :failed)
                 .exists?
  end

  def parse_message_and_cta_url(message)
    raw = Array(message).first
    if raw.is_a?(Hash)
      hash = raw.with_indifferent_access
      return [hash[:content].to_s, hash[:cta_url]]
    end

    text = raw.to_s
    cta = extract_inline_cta_tag(text)
    if cta
      cleaned = text.sub(/\[CTA_URL:\s*([^|\]]+?)\s*\|\s*(https?:\/\/[^\s\]]+)\s*\]/i, '').strip
      return [cleaned, cta]
    end

    auto_cta = infer_whatsapp_cloud_cta_url(text)
    [text, auto_cta]
  end

  def extract_inline_cta_tag(text)
    match = text.match(/\[CTA_URL:\s*([^|\]]+?)\s*\|\s*(https?:\/\/[^\s\]]+)\s*\]/i)
    return nil unless match

    {
      'display_text' => match[1].strip.first(20),
      'url' => match[2].strip,
      'footer_text' => 'Canal exclusivo de notificações'
    }
  end

  def infer_whatsapp_cloud_cta_url(text)
    channel = @conversation.inbox&.channel
    return nil unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'

    url_match = text.match(%r{https?://[^\s*)]+}i)
    return nil unless url_match

    {
      'display_text' => 'Falar no Chat Agora',
      'url' => url_match[0].sub(/[.,;]+$/, ''),
      'footer_text' => 'Atendimento todos os dias, 11h às 22h'
    }
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.with(account: @account)
                                                     .conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end

  def scheduled_message_attachment_blob(blob_id)
    return if blob_id.blank?

    attachment = @rule.files.find { |file| file.blob_id == blob_id.to_i }
    attachment&.blob
  end
end

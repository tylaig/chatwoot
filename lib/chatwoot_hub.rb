class ChatwootHub
  DEFAULT_BASE_URL = ENV.fetch('MSC_HUB_URL', 'https://chat.meusuper.app').freeze

  def self.base_url
    DEFAULT_BASE_URL
  end

  def self.ping_url
    "#{base_url}/ping"
  end

  def self.registration_url
    "#{base_url}/instances"
  end

  def self.push_notification_url
    ENV.fetch('MSC_PUSH_RELAY_URL', '').presence
  end

  def self.events_url
    "#{base_url}/events"
  end

  def self.billing_base_url
    '/super_admin/settings'
  end

  def self.installation_identifier
    identifier = InstallationConfig.find_by(name: 'INSTALLATION_IDENTIFIER')&.value
    identifier ||= InstallationConfig.create!(name: 'INSTALLATION_IDENTIFIER', value: SecureRandom.uuid).value
    identifier
  end

  def self.billing_url
    billing_base_url
  end

  def self.pricing_plan
    return 'enterprise' if defined?(EliteLicenseEngine) && EliteLicenseEngine.active?
    return 'community' unless ChatwootApp.enterprise?

    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'enterprise'
  end

  def self.pricing_plan_quantity
    if defined?(EliteLicenseEngine) && EliteLicenseEngine.active?
      return EliteLicenseEngine.current_limits[:max_agents]
    end
    return 0 unless ChatwootApp.enterprise?

    InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.value || 10_000
  end

  def self.support_config
    {
      support_website_token: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN')&.value,
      support_script_url: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL')&.value,
      support_identifier_hash: InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH')&.value
    }
  end

  def self.instance_config
    {
      installation_identifier: installation_identifier,
      installation_version: Chatwoot.config[:version],
      installation_host: (URI.parse(ENV.fetch('FRONTEND_URL', '')).host rescue ''),
      installation_env: ENV.fetch('INSTALLATION_ENV', 'meusuperchat'),
      edition: 'meusuperchat-elite'
    }
  end

  def self.instance_metrics
    {
      accounts_count: fetch_count(Account),
      users_count: fetch_count(User),
      inboxes_count: fetch_count(Inbox),
      conversations_count: fetch_count(Conversation),
      incoming_messages_count: fetch_count(Message.incoming),
      outgoing_messages_count: fetch_count(Message.outgoing),
      additional_information: {}
    }
  end

  def self.fetch_count(model)
    model.last&.id || 0
  end

  def self.sync_with_hub
    {
      'version' => Chatwoot.config[:version],
      'plan' => 'enterprise',
      'plan_quantity' => pricing_plan_quantity,
      'elite_tier' => (defined?(EliteLicenseEngine) ? EliteLicenseEngine.current_tier_key : 'elite_whitelabel'),
      'verified_locally' => true
    }
  end

  def self.register_instance(_company_name, _owner_name, _owner_email)
    true
  end

  def self.send_push(fcm_options)
    return false if push_notification_url.blank?

    send_push_with_response(fcm_options)
  rescue *ExceptionList::REST_CLIENT_EXCEPTIONS => e
    Rails.logger.error "Exception: #{e.message}"
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  def self.send_push_with_response(fcm_options)
    return nil if push_notification_url.blank?

    info = { fcm_options: fcm_options }
    RestClient.post(push_notification_url, info.merge(instance_config).to_json, { content_type: :json, accept: :json })
  end

  def self.emit_event(_event_name, _event_data)
    true
  end
end

ChatwootHub.singleton_class.prepend_mod_with('ChatwootHub')

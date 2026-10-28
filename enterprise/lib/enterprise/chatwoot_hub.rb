module Enterprise::ChatwootHub
  ENTERPRISE_BASE_URL = ENV.fetch('MSC_HUB_URL', 'https://chat.meusuper.app').freeze

  def base_url
    ENTERPRISE_BASE_URL
  end
end

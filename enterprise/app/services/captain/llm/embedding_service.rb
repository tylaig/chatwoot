class Captain::Llm::EmbeddingService
  include Integrations::LlmInstrumentation

  class EmbeddingsError < StandardError; end

  LOCAL_EMBEDDING_URL = ENV.fetch('LOCAL_EMBEDDING_URL', 'http://chatwoot_embedding:8000/v1/embeddings')

  def initialize(account_id: nil)
    Llm::Config.initialize!
    @account_id = account_id
    @embedding_model = self.class.embedding_model
  end

  def self.embedding_model
    InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL')&.value.presence || LlmConstants::DEFAULT_EMBEDDING_MODEL
  end

  def get_embedding(content, model: @embedding_model)
    return [] if content.blank?

    fetch_local_embedding(content, model)
  rescue StandardError => e
    Rails.logger.warn("Local Embedding fallback triggered: #{e.message}")
    begin
      instrument_embedding_call(instrumentation_params(content, model)) do
        RubyLLM.embed(content, model: model).vectors
      end
    rescue StandardError => llm_err
      Rails.logger.error "Embedding API Error: #{llm_err.message}"
      raise EmbeddingsError, "Failed to create an embedding: #{llm_err.message}"
    end
  end

  private

  def fetch_local_embedding(content, model)
    uri = URI(LOCAL_EMBEDDING_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 3
    http.read_timeout = 10
    req = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    req.body = { input: content, model: model }.to_json
    res = http.request(req)
    raise "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    data = JSON.parse(res.body)
    vec = data.dig('data', 0, 'embedding')
    raise 'Empty embedding vector' if vec.blank?

    vec
  end

  def instrumentation_params(content, model)
    {
      span_name: 'llm.captain.embedding',
      model: model,
      input: content,
      feature_name: 'embedding',
      account_id: @account_id
    }
  end
end

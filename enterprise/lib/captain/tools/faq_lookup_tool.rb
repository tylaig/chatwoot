class Captain::Tools::FaqLookupTool < Captain::Tools::BasePublicTool
  description 'Search FAQ responses using semantic similarity to find relevant answers'
  param :query, type: 'string', desc: 'The question or topic to search for in the FAQ database'

  STOPWORDS = %w[
    de da do das dos em no na nos nas um uma uns umas para por com sem sob sobre
    que qual quais como onde quando quem porque porquê pois mas porem contudo
    todavia entretanto ou e nem se ao aos as os o a é são foi foram ser estar
    ter haver fazer poder dever querer saber ver dar dizer falar pedir precisar
    ajuda dúvida duvida cliente loja compra pedido meu minha meus minhas nao não
    ta tá to tô pro pra ai aí la lá
  ].freeze

  def perform(tool_context, query:)
    log_tool_usage('searching', { query: query })

    responses = hybrid_search(query)
    record_retrieved_sources(tool_context, responses)

    if responses.empty?
      log_tool_usage('no_results', { query: query })
      "No relevant FAQs found for: #{query}"
    else
      log_tool_usage('found_results', { query: query, count: responses.size })
      format_responses(tool_context, responses)
    end
  end

  private

  def hybrid_search(query)
    results = []

    # 1. Exact substring match
    exact = @assistant.responses.approved
                      .where('question ILIKE :q OR answer ILIKE :q', q: "%#{query}%")
                      .includes(:documentable).limit(3).to_a
    results.concat(exact)

    # 2. PostgreSQL Full-Text Search in Portuguese
    fts_matches = @assistant.responses.approved
                            .where("to_tsvector('portuguese', coalesce(question,'') || ' ' || coalesce(answer,'')) @@ plainto_tsquery('portuguese', :q)", q: query)
                            .includes(:documentable).limit(3).to_a
    results.concat(fts_matches)

    # 3. Keyword scoring in Portuguese (question weighted 3x, answer 1x)
    keywords = query.to_s.downcase.scan(/[[:alnum:]]{3,}/) - STOPWORDS
    if keywords.any?
      conditions = keywords.first(6).map do |kw|
        ActiveRecord::Base.sanitize_sql_array(
          ['(CASE WHEN question ILIKE ? THEN 3 ELSE 0 END + CASE WHEN answer ILIKE ? THEN 1 ELSE 0 END)', "%#{kw}%", "%#{kw}%"]
        )
      end.join(' + ')
      kw_matches = @assistant.responses.approved
                             .where(keywords.first(6).map { 'question ILIKE ? OR answer ILIKE ?' }.join(' OR '), *keywords.first(6).flat_map { |kw| ["%#{kw}%", "%#{kw}%"] })
                             .order(Arel.sql("(#{conditions}) DESC"))
                             .includes(:documentable).limit(3).to_a
      results.concat(kw_matches)
    end

    # 4. Vector semantic search (via local multilingual embedding service)
    begin
      vec_matches = @assistant.responses.approved.search(query).includes(:documentable).limit(4).to_a
      results.concat(vec_matches)
    rescue StandardError => e
      Rails.logger.warn("[Captain] FAQ vector lookup fallback: #{e.message}")
    end

    results.uniq(&:id).first(6)
  end

  def safe_to_run_after_new_customer_message?
    true
  end

  def record_retrieved_sources(tool_context, responses)
    return if responses.empty?

    metadata = tool_context.state[:cw_metadata] ||= {}
    metadata[:faq_ids] = Array(metadata[:faq_ids]) | responses.map(&:id)

    responses_by_type = responses.group_by(&:documentable_type)
    document_ids = Array(responses_by_type['Captain::Document']).map(&:documentable_id)
    metadata[:document_ids] = Array(metadata[:document_ids]) | document_ids

    used_faq_ids = Array(responses_by_type['User']).map(&:id)
    metadata[:used_faq_ids] = Array(metadata[:used_faq_ids]) | used_faq_ids
  end

  def format_responses(tool_context, responses)
    responses.map { |response| format_response(tool_context, response) }.join
  end

  def format_response(tool_context, response)
    formatted_response = "
        FAQ result:
        "
    if @assistant.citations_enabled? && response.customer_visible_source_url.present?
      formatted_response += "
          Citation index: #{citation_index(tool_context, response)}
          "
    end
    formatted_response += "
        Question: #{response.question}
        Answer: #{response.answer}
        "

    formatted_response
  end

  def citation_index(tool_context, response)
    citation_document_ids = tool_context.state[Captain::Assistant::CITATION_SOURCES_STATE_KEY] ||= {}
    existing_index = citation_document_ids.find { |_index, document_id| document_id == response.documentable_id }&.first
    return existing_index if existing_index.present?

    next_citation_index = citation_document_ids.size + 1
    citation_document_ids[next_citation_index] = response.documentable_id
    next_citation_index
  end
end

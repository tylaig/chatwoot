class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  CLOSING_CODE_FENCE_LINE = /\A(?:`{3,}|~{3,})\z/
  RESOLUTION_MARKER_REGEX = %r{<conversation_boundary\b[^>]*status\s*=\s*["'“”]resolved["'“”][^>]*/?>}i
  GENERIC_BOUNDARY_MARKER_REGEX = %r{</?conversation_boundary\b[^>]*>}i

  attr_reader :parts

  def self.contains_resolution_marker?(text)
    text.to_s.match?(RESOLUTION_MARKER_REGEX)
  end

  def self.strip_internal_markers(text)
    text.to_s.gsub(GENERIC_BOUNDARY_MARKER_REGEX, '').gsub(/\n{3,}/, "\n\n").strip
  end

  def self.from_response(response)
    return new([{ text: response.to_s, citation_indexes: [] }]) unless response.is_a?(Hash)

    response = response.with_indifferent_access
    return new(response[:response_parts]) if response.key?(:response_parts)

    new([{ text: response[:response], citation_indexes: [] }])
  end

  def initialize(response_parts)
    @parts = Array(response_parts).filter_map { |part| normalize_part(part) }
  end

  def plain_text
    parts.pluck('text').join("\n\n")
  end

  def without_citations
    self.class.new(parts.map { |part| part.merge('citation_indexes' => []) })
  end

  def customer_message_content(citation_urls: {})
    display_numbers = {}

    parts.map do |part|
      links = part['citation_indexes'].filter_map do |citation_index|
        url = citation_urls[citation_index]
        next if url.blank?

        # Number trusted sources by first appearance and reuse that number for later references.
        display_number = display_numbers[url] ||= display_numbers.size + 1
        markdown_safe_url = url.gsub('(', '%28').gsub(')', '%29')
        "[[#{display_number}](#{markdown_safe_url})]"
      end.uniq

      final_text_line = part['text'].lines.last.to_s.strip
      citation_separator = final_text_line.match?(CLOSING_CODE_FENCE_LINE) ? "\n" : ' '
      [part['text'], links.join(' ')].compact_blank.join(citation_separator)
    end.join("\n\n")
  end

  def to_a
    parts
  end

  private

  def normalize_part(part)
    return unless part.is_a?(Hash)

    part = part.with_indifferent_access
    return unless part[:text].is_a?(String)

    text = self.class.strip_internal_markers(part[:text])
    return if text.blank?

    {
      'text' => text,
      'citation_indexes' => Array(part[:citation_indexes]).select do |citation_index|
        citation_index.is_a?(Integer) && citation_index.positive?
      end.uniq
    }
  end
end

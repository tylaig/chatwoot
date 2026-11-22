class Captain::Assistant::ResponseParts
  MESSAGE_ATTRIBUTE_KEY = 'captain_v2_response_parts'.freeze
  CLOSING_CODE_FENCE_LINE = /\A(?:`{3,}|~{3,})\z/
  RESOLUTION_MARKER_REGEX = %r{<conversation_boundary\b[^>]*status\s*=\s*["'“”]resolved["'“”][^>]*/?>}i
  GENERIC_BOUNDARY_MARKER_REGEX = %r{</?conversation_boundary\b[^>]*>}i
  CTRL_CHAR_REGEX = /[\x00-\x08\x0b\x0c\x0e-\x1f]/
  STRIP_CTRL_REGEX = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/
  TOOL_CALL_LEAK_BLOCK_REGEX = /\A\s*(?:\[Tool\s*call\])?\s*(?:Function\s+call\s+requested[\s\S]*|Tool\s*calls?:[\s\S]*)\z/i

  attr_reader :parts

  def self.contains_resolution_marker?(text)
    text.to_s.match?(RESOLUTION_MARKER_REGEX)
  end

  def self.sanitize_corrupted_accents(text)
    str = text.to_s.dup
    return str unless str.match?(STRIP_CTRL_REGEX)

    str.gsub!(/(\p{L})#{CTRL_CHAR_REGEX}{2}o\b/i) { "#{$1}ção" }
    str.gsub!(/(\p{L})#{CTRL_CHAR_REGEX}{2}es\b/i) { "#{$1}ções" }
    str.gsub!(/\bn#{CTRL_CHAR_REGEX}o\b/i) { |m| m[0] == "N" ? "Não" : "não" }
    str.gsub!(/(\p{L})#{CTRL_CHAR_REGEX}o\b/i) { "#{$1}ão" }
    str.gsub!(/(\p{L})#{CTRL_CHAR_REGEX}vel\b/i) { "#{$1}ível" }
    str.gsub!(/(\p{L})#{CTRL_CHAR_REGEX}veis\b/i) { "#{$1}íveis" }
    str.gsub!(/v#{CTRL_CHAR_REGEX}deo/i) { |m| m[0] == "V" ? "Vídeo" : "vídeo" }
    str.gsub!(/c#{CTRL_CHAR_REGEX}digo/i) { |m| m[0] == "C" ? "Código" : "código" }
    str.gsub!(/d#{CTRL_CHAR_REGEX}vida/i) { |m| m[0] == "D" ? "Dúvida" : "dúvida" }
    str.gsub!(/d#{CTRL_CHAR_REGEX}gitos/i) { |m| m[0] == "D" ? "Dígitos" : "dígitos" }
    str.gsub!(/m#{CTRL_CHAR_REGEX}dia/i) { |m| m[0] == "M" ? "Mídia" : "mídia" }
    str.gsub!(/pr#{CTRL_CHAR_REGEX}-venda/i) { |m| m[0] == "P" ? "Pré-venda" : "pré-venda" }
    str.gsub!(/voc#{CTRL_CHAR_REGEX}(?!\p{L})/i) { |m| m[0] == "V" ? "Você" : "você" }
    str.gsub!(/tamb#{CTRL_CHAR_REGEX}m\b/i) { |m| m[0] == "T" ? "Também" : "também" }
    str.gsub!(/est#{CTRL_CHAR_REGEX}(?!\p{L})/i) { |m| m[0] == "E" ? "Está" : "está" }
    str.gsub!(/\bj#{CTRL_CHAR_REGEX}(?!\p{L})/i) { |m| m[0] == "J" ? "Já" : "já" }
    str.gsub!(/\bs#{CTRL_CHAR_REGEX}(?!\p{L})/i) { |m| m[0] == "S" ? "Só" : "só" }
    str.gsub!(/\bat#{CTRL_CHAR_REGEX}(?!\p{L})/i) { |m| m[0] == "A" ? "Até" : "até" }
    str.gsub!(/\bap#{CTRL_CHAR_REGEX}s\b/i) { |m| m[0] == "A" ? "Após" : "após" }
    str.gsub!(STRIP_CTRL_REGEX, "")
    str
  end

  def self.tool_call_leak?(text)
    str = text.to_s
    return true if str.match?(TOOL_CALL_LEAK_BLOCK_REGEX)
    return true if str.match?(/\[Tool\s*call\]/i) && str.match?(/Function\s+call\s+requested/i)
    return true if str.match?(/Function\s+call\s+requested\s*:\s*tool_\d+/i)

    false
  end

  def self.strip_tool_call_leak(text)
    cleaned = text.to_s.dup
    cleaned.gsub!(/\[Tool\s*call\]\s*/i, '')
    cleaned.gsub!(/Function\s+call\s+requested\s*:\s*tool_\d+\s*/i, '')
    cleaned.gsub!(/(?:^|\n)\s*Arguments\s*:\s*\{[\s\S]*?\}\s*/i, '')
    cleaned.gsub!(/(?:^|\n)\s*Tool\s*calls?:\s*[^\n]*/i, '')
    cleaned.strip
  end

  def self.strip_internal_markers(text)
    cleaned = sanitize_corrupted_accents(CGI.unescapeHTML(text.to_s))
    cleaned = cleaned.gsub(GENERIC_BOUNDARY_MARKER_REGEX, '')
    cleaned = strip_tool_call_leak(cleaned)
    cleaned.gsub(/\n{3,}/, "\n\n").strip
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
    return if self.class.tool_call_leak?(text)

    {
      'text' => text,
      'citation_indexes' => Array(part[:citation_indexes]).select do |citation_index|
        citation_index.is_a?(Integer) && citation_index.positive?
      end.uniq
    }
  end
end

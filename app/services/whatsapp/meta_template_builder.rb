# frozen_string_literal: true

class Whatsapp::MetaTemplateBuilder
  TOKEN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/
  NAMED_PARAM = /\A[a-z][a-z0-9_]{0,19}\z/
  META_CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze

  def initialize(template, require_examples: true)
    @template = template
    @require_examples = require_examples
    @errors = []
  end

  attr_reader :errors

  def valid?
    @errors = []
    validate_category
    validate_body
    validate_header
    validate_footer
    validate_buttons
    errors.empty?
  end

  def parameter_format
    named_params?(tokens(body_text)) ? 'NAMED' : 'POSITIONAL'
  end

  def graph_category
    category == 'MARKETING_LITE' ? 'MARKETING' : category
  end

  def graph_payload
    {
      name: @template.name,
      language: @template.language,
      category: graph_category,
      parameter_format: parameter_format,
      components: components
    }
  end

  private

  def category
    @template.category.to_s
  end

  def body_text
    @template.body.to_s
  end

  def validate_category
    return if META_CATEGORIES.include?(graph_category)

    @errors << 'Categoria inválida para a Meta. Use Marketing, Marketing Lite ou Utilidade.'
  end

  def validate_body
    if body_text.blank?
      @errors << 'O corpo da mensagem é obrigatório.'
      return
    end
    @errors << 'O corpo da mensagem pode ter no máximo 1024 caracteres.' if body_text.length > 1024
    validate_parameter_text('corpo', body_text, 'body')
  end

  def validate_header
    type = @template.header_type.to_s
    return if type.blank? || type == 'NONE'

    if type == 'TEXT'
      text = @template.header_content.to_s
      if text.blank?
        @errors << 'Informe o texto do cabeçalho ou escolha Nenhum.'
        return
      end
      @errors << 'O cabeçalho de texto pode ter no máximo 60 caracteres.' if text.length > 60
      found = tokens(text)
      @errors << 'O cabeçalho de texto aceita no máximo uma variável.' if found.size > 1
      validate_parameter_text('cabeçalho', text, 'header')
      return
    end

    unless %w[IMAGE VIDEO DOCUMENT].include?(type)
      @errors << 'Tipo de cabeçalho não suportado pela Meta.'
      return
    end

    url = @template.header_content.to_s.strip
    if url.blank?
      @errors << 'Envie um arquivo para o armazenamento do Chatwoot.'
      return
    end
    unless url.match?(%r{\Ahttps?://}i)
      @errors << 'O arquivo precisa estar no armazenamento do Chatwoot.'
      return
    end
    return unless @require_examples
    return if url.match?(%r{\Ahttps://}i)

    @errors << 'Para enviar à Meta, o arquivo salvo no Chatwoot precisa de um endereço https público.'
  end

  def validate_footer
    footer = @template.footer.to_s
    return if footer.blank?

    @errors << 'O rodapé pode ter no máximo 60 caracteres.' if footer.length > 60
    @errors << 'A Meta não permite variáveis no rodapé.' if tokens(footer).any?
  end

  def validate_buttons
    buttons = Array(@template.buttons)
    @errors << 'A Meta permite no máximo 10 botões.' if buttons.size > 10
    buttons.each_with_index do |button, index|
      validate_button(button.to_h.with_indifferent_access, index + 1)
    end
  end

  def validate_button(button, position)
    text = button[:text].to_s.strip
    @errors << "Botão #{position}: informe o texto (máximo 25 caracteres)." if text.blank? || text.length > 25
    case button[:type].to_s
    when 'URL'
      url = button[:url].to_s.strip
      @errors << "Botão #{position}: a URL deve começar com https://." unless url.match?(%r{\Ahttps://}i)
      url_tokens = tokens(url)
      if url_tokens.any? && (url_tokens != ['1'] || !url.match?(/\{\{\s*1\s*\}\}\z/))
        @errors << "Botão #{position}: a URL aceita só a variável {{1}} no final."
      end
    when 'PHONE_NUMBER'
      phone = button[:phone_number].to_s.gsub(/[^\d+]/, '')
      @errors << "Botão #{position}: informe o telefone com código do país." unless phone.match?(/\A\+?[1-9]\d{7,14}\z/)
    when 'QUICK_REPLY'
      nil
    else
      @errors << "Botão #{position}: tipo inválido."
    end
  end

  def validate_parameter_text(label, text, component)
    stripped = text.strip
    if stripped.match?(/\A\{\{/) || stripped.match?(/\}\}\s*\z/)
      @errors << "A Meta não permite variável no início ou no fim do #{label}."
    end

    found = tokens(text)
    return if found.empty?

    if found.any? { |token| token.match?(/\A\d+\z/) } && found.any? { |token| !token.match?(/\A\d+\z/) }
      @errors << "O #{label} não pode misturar variáveis nomeadas e numéricas."
      return
    end

    if found.all? { |token| token.match?(/\A\d+\z/) }
      numbers = found.map(&:to_i)
      expected = (1..numbers.max).to_a
      unless numbers.uniq.sort == expected && numbers == expected
        @errors << "As variáveis do #{label} devem ser {{1}}, {{2}}... sem repetir e sem pular números."
      end
    else
      found.each do |token|
        next if token.match?(NAMED_PARAM)

        @errors << "A variável {{#{token}}} deve começar com letra minúscula e ter no máximo 20 caracteres."
      end
      @errors << "As variáveis do #{label} não podem se repetir." if found.uniq.size != found.size
    end

    return unless @require_examples

    found.uniq.each do |token|
      sample = sample_for(component, token)
      @errors << "Informe um exemplo para {{#{token}}}." if sample.blank?
    end
  end

  def sample_for(component, key)
    Array(@template.variables).find do |variable|
      item = variable.to_h.with_indifferent_access
      item[:key].to_s == key && (item[:component].blank? || item[:component].to_s == component)
    end&.to_h&.with_indifferent_access&.dig(:sample_value)
  end

  def tokens(text)
    text.to_s.scan(TOKEN).flatten
  end

  def named_params?(found)
    found.any? && found.none? { |token| token.match?(/\A\d+\z/) }
  end

  def components
    list = []
    list << header_component if header_component
    list << body_component
    list << { type: 'FOOTER', text: @template.footer } if @template.footer.present?
    list << buttons_component if Array(@template.buttons).any?
    list
  end

  def header_component
    type = @template.header_type.to_s
    return if type.blank? || type == 'NONE'

    if type == 'TEXT'
      component = { type: 'HEADER', format: 'TEXT', text: @template.header_content }
      found = tokens(@template.header_content)
      component[:example] = text_example('header', found) if found.any?
      return component
    end

    {
      type: 'HEADER',
      format: type,
      example: { header_handle: [@template.header_content] }
    }
  end

  def body_component
    found = tokens(body_text)
    component = { type: 'BODY', text: body_text }
    component[:example] = text_example('body', found) if found.any?
    component
  end

  def text_example(component, found)
    examples = found.uniq.map { |token| sample_for(component, token).to_s }
    if named_params?(found)
      key = component == 'header' ? :header_text_named_params : :body_text_named_params
      {
        key => found.uniq.each_with_index.map do |token, index|
          { param_name: token, example: examples[index] }
        end
      }
    elsif component == 'header'
      { header_text: examples }
    else
      { body_text: [examples] }
    end
  end

  def buttons_component
    ordered = Array(@template.buttons).sort_by { |button| button.to_h['type'].to_s == 'QUICK_REPLY' ? 1 : 0 }
    {
      type: 'BUTTONS',
      buttons: ordered.map { |button| button_payload(button.to_h.with_indifferent_access) }
    }
  end

  def button_payload(button)
    text = button[:text].to_s
    case button[:type].to_s
    when 'URL'
      payload = { type: 'URL', text: text, url: button[:url].to_s }
      payload[:example] = [button[:url].to_s.sub(/\{\{\s*1\s*\}\}/, 'exemplo')] if tokens(button[:url]).any?
      payload
    when 'PHONE_NUMBER'
      { type: 'PHONE_NUMBER', text: text, phone_number: button[:phone_number].to_s.gsub(/[^\d+]/, '') }
    else
      { type: 'QUICK_REPLY', text: text }
    end
  end
end

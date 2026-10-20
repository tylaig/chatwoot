class Whatsapp::TemplateProcessorService
  pattr_initialize [:channel!, :template_params, :message]

  def call
    return [nil, nil, nil, nil] if template_params.blank?

    process_template_with_params
  end

  private

  def process_template_with_params
    [
      template_params['name'],
      template_params['namespace'],
      template_params['language'],
      processed_templates_params
    ]
  end

  def find_template
    cached = Array(channel.message_templates).find do |item|
      item['name'] == template_params['name'] &&
        item['language'].to_s.casecmp(template_params['language'].to_s).zero? &&
        item['status'].to_s.casecmp('approved').zero?
    end
    return with_parameter_format(cached) if cached

    record = account_template
    return if record.blank?

    with_parameter_format(template_from_record(record))
  end

  def account_template
    account = channel.inbox&.account
    return if account.blank?

    scope = account.whatsapp_templates.approved.where(name: template_params['name'])
    language = template_params['language'].to_s
    scope.find_by(language: language) || scope.where('LOWER(language) = ?', language.downcase).first
  end

  def template_from_record(record)
    components = []
    if record.header_type == 'TEXT' && record.header_content.present?
      components << { 'type' => 'HEADER', 'format' => 'TEXT', 'text' => record.header_content }
    elsif %w[IMAGE VIDEO DOCUMENT].include?(record.header_type)
      components << { 'type' => 'HEADER', 'format' => record.header_type }
    end
    components << { 'type' => 'BODY', 'text' => record.body }
    {
      'name' => record.name,
      'language' => record.language,
      'status' => 'APPROVED',
      'components' => components
    }
  end

  def with_parameter_format(template)
    return template if template['parameter_format'].present?

    body = Array(template['components']).find { |component| component['type'] == 'BODY' }&.[]('text')
    tokens = body.to_s.scan(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/).flatten
    format = tokens.any? { |token| token.match?(/\A[a-z]/) } ? 'NAMED' : 'POSITIONAL'
    template.merge('parameter_format' => format)
  end

  def processed_templates_params
    template = find_template
    return if template.blank?

    # Convert legacy format to enhanced format before processing
    converter = Whatsapp::TemplateParameterConverterService.new(template_params, template)
    normalized_params = converter.normalize_to_enhanced

    process_enhanced_template_params(template, normalized_params['processed_params'])
  end

  def process_enhanced_template_params(template, processed_params = nil)
    processed_params ||= template_params['processed_params']
    components = []

    components.concat(process_header_components(processed_params, template))
    components.concat(process_body_components(processed_params, template))
    components.concat(process_footer_components(processed_params))
    components.concat(process_button_components(processed_params))

    @template_params = components
  end

  def process_header_components(processed_params, template)
    return [] if processed_params['header'].blank?

    header_params = build_header_params(processed_params['header'], template)
    header_params.present? ? [{ type: 'header', parameters: header_params }] : []
  end

  def build_header_params(header_data, template)
    header_component = template['components']&.find { |component| component['type'] == 'HEADER' }
    return build_text_header_params(header_data, template) if header_component&.dig('format') == 'TEXT'

    build_media_header_params(header_data, template)
  end

  def build_text_header_params(header_data, template)
    header_data.filter_map do |key, value|
      build_text_parameter(key, value, template) if value.present?
    end
  end

  def build_media_header_params(header_data, template)
    return [] if header_data['media_url'].blank? || header_data['media_type'].blank?

    media_param = parameter_builder.build_media_parameter(
      media_source(header_data['media_url'], template), header_data['media_type'], header_data['media_name']
    )
    media_param ? [media_param] : []
  end

  # Agents send the template's own sample media most of the time, and that URL can only be delivered as
  # an uploaded media id, see Whatsapp::TemplateSampleMediaService. A URL the agent supplied is theirs
  # to host, so it goes out as a plain link.
  def media_source(media_url, template)
    handle = sample_media_handle(media_url, template)
    return { link: media_url } if handle.blank?

    { id: Whatsapp::TemplateSampleMediaService.new(channel: channel, url: handle).media_id }
  end

  # Returns the handle the template carries right now, which is not always the string that was stored.
  # Meta re-signs the sample URL and the sync picks up the new signature every few hours, so a scheduled
  # message or a campaign can carry a signature that has since rotated. The path identifies the file, so
  # match on that and upload the current handle rather than the stale one.
  def sample_media_handle(media_url, template)
    return nil unless channel.provider == 'whatsapp_cloud'

    header = Array(template['components']).find { |component| component['type'] == 'HEADER' }
    Array(header&.dig('example', 'header_handle')).find { |handle| same_media?(handle, media_url) }
  end

  def same_media?(handle, media_url)
    return true if handle == media_url

    Addressable::URI.parse(handle).omit(:query, :fragment) == Addressable::URI.parse(media_url).omit(:query, :fragment)
  rescue Addressable::URI::InvalidURIError
    false
  end

  def process_body_components(processed_params, template)
    return [] if processed_params['body'].blank?

    body_parameters = processed_params['body']
    body_parameters = body_parameters.sort_by { |key, _value| key.to_i } unless template['parameter_format'] == 'NAMED'

    body_params = body_parameters.filter_map do |key, value|
      next if value.blank?

      build_text_parameter(key, value, template)
    end

    body_params.present? ? [{ type: 'body', parameters: body_params }] : []
  end

  def build_text_parameter(key, value, template)
    return parameter_builder.build_named_parameter(key, value) if template['parameter_format'] == 'NAMED'

    parameter_builder.build_parameter(value)
  end

  def process_footer_components(processed_params)
    return [] if processed_params['footer'].blank?

    footer_params = processed_params['footer'].filter_map do |_, value|
      next if value.blank?

      parameter_builder.build_parameter(value)
    end

    footer_params.present? ? [{ type: 'footer', parameters: footer_params }] : []
  end

  def process_button_components(processed_params)
    return [] if processed_params['buttons'].blank?

    button_params = processed_params['buttons'].filter_map.with_index do |button, index|
      next if button.blank?

      if button['type'] == 'url' || button['parameter'].present?
        {
          type: 'button',
          sub_type: button['type'] || 'url',
          index: index,
          parameters: [parameter_builder.build_button_parameter(button)]
        }
      end
    end

    button_params.compact
  end

  def parameter_builder
    @parameter_builder ||= Whatsapp::PopulateTemplateParametersService.new
  end
end

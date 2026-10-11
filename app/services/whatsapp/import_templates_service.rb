# frozen_string_literal: true

class Whatsapp::ImportTemplatesService
  STATUS_MAP = {
    'APPROVED' => 'APPROVED',
    'PENDING' => 'PENDING',
    'REJECTED' => 'REJECTED',
    'PAUSED' => 'PAUSED',
    'DISABLED' => 'PAUSED',
    'IN_APPEAL' => 'PENDING',
    'PENDING_DELETION' => 'PAUSED'
  }.freeze

  def initialize(account)
    @account = account
  end

  def perform
    channels = cloud_channels
    if channels.empty?
      return failure('Nenhuma inbox WhatsApp Cloud está conectada. Conecte o número da Meta para sincronizar os templates.')
    end

    created = 0
    updated = 0
    errors = []

    channels.each do |channel|
      fetched = fetch_templates(channel)
      if fetched[:error]
        errors << fetched[:error]
        next
      end

      store_channel_templates(channel, fetched[:templates])
      fetched[:templates].each do |payload|
        case import_payload(channel.inbox, payload)
        when :created then created += 1
        when :updated then updated += 1
        end
      end
    end

    if created.zero? && updated.zero?
      return failure(errors.first || 'A Meta não devolveu templates para importar.')
    end

    {
      success: true,
      created: created,
      updated: updated,
      message: "Sincronização concluída. #{created} novos e #{updated} atualizados."
    }
  end

  private

  def cloud_channels
    @account.inboxes.includes(:channel).filter_map do |inbox|
      channel = inbox.channel
      channel if cloud?(channel)
    end
  end

  def cloud?(channel)
    return false unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud'

    config = channel.provider_config
    config.is_a?(Hash) && config['business_account_id'].present? && config['api_key'].present?
  end

  def fetch_templates(channel)
    collected = []
    cursor = nil

    20.times do
      page = template_page(channel, cursor)
      return { error: page } if page.is_a?(String)

      collected.concat(Array(page['data']))
      cursor = page.dig('paging', 'cursors', 'after')
      break if cursor.blank?
    end

    { templates: collected }
  end

  def template_page(channel, cursor)
    waba_id = channel.provider_config['business_account_id']
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    options = { headers: { 'Authorization' => "Bearer #{channel.template_access_token}" } }
    options[:query] = { after: cursor } if cursor.present?
    response = HTTParty.get("#{base_url}/v14.0/#{waba_id}/message_templates", options)
    body = response.parsed_response
    return body if response.success? && body.is_a?(Hash)

    message = body.is_a?(Hash) ? body.dig('error', 'message') : nil
    message.presence || 'A Meta recusou a sincronização dos templates.'
  rescue StandardError
    'Não foi possível falar com a Meta para sincronizar os templates.'
  end

  def store_channel_templates(channel, templates)
    changed = templates != channel.message_templates
    channel.update_columns(message_templates: templates, message_templates_last_updated: Time.current) # rubocop:disable Rails/SkipsModelValidations
    channel.account.update_cache_key('inbox') if changed
  end

  def import_payload(inbox, payload)
    name = payload['name'].to_s
    return :skipped unless name.match?(/\A[a-z0-9_]+\z/)

    components = Array(payload['components'])
    body = component_text(components, 'BODY').truncate(1024, omission: '')
    return :skipped if body.blank?

    record = @account.whatsapp_templates.find_or_initialize_by(
      name: name,
      language: payload['language'].presence || 'pt_BR'
    )
    created = record.new_record?
    assign_record(record, inbox, payload, components, body)
    record.save!
    created ? :created : :updated
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
    :skipped
  end

  def assign_record(record, inbox, payload, components, body)
    header = header_from(components)
    record.inbox = inbox
    record.category = mapped_category(payload['category'])
    record.status = STATUS_MAP[payload['status']] || 'PENDING'
    record.body = body
    record.footer = component_text(components, 'FOOTER').truncate(60, omission: '')
    record.header_type = header[:type]
    record.header_content = header[:content] if header[:content].present? || %w[NONE TEXT].include?(header[:type])
    record.buttons = buttons_from(components)
    record.variables = variables_from(components, body)
    record.meta_template_id = payload['id']
    reason = payload['rejected_reason'].to_s
    record.rejection_reason = reason.truncate(255, omission: '') if reason.present? && reason != 'NONE'
  end

  def mapped_category(category)
    value = category.to_s
    return value if WhatsappTemplate::CATEGORIES.include?(value)

    'MARKETING'
  end

  def component_text(components, type)
    components.find { |item| item['type'] == type }&.[]('text').to_s
  end

  def header_from(components)
    header = components.find { |item| item['type'] == 'HEADER' }
    return { type: 'NONE', content: '' } unless header

    format = header['format'].to_s
    return { type: 'TEXT', content: header['text'].to_s.truncate(60, omission: '') } if format == 'TEXT'
    return media_header(format, header) if %w[IMAGE VIDEO DOCUMENT].include?(format)

    { type: 'NONE', content: '' }
  end

  def media_header(format, header)
    handle = Array(header.dig('example', 'header_handle')).first.to_s
    content = handle.start_with?('http') ? handle : ''
    { type: format, content: content }
  end

  def buttons_from(components)
    buttons = components.find { |item| item['type'] == 'BUTTONS' }
    Array(buttons&.[]('buttons')).filter_map do |button|
      text = button['text'].to_s
      next if text.blank?

      {
        'type' => button['type'],
        'text' => text.truncate(25, omission: ''),
        'url' => button['url'],
        'phone_number' => button['phone_number']
      }.compact
    end
  end

  def variables_from(components, body)
    body_component = components.find { |item| item['type'] == 'BODY' }
    examples = Array(body_component&.dig('example', 'body_text')).first || []
    named = Array(body_component&.dig('example', 'body_text_named_params'))
    body.scan(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/).flatten.uniq.map.with_index do |key, index|
      sample = named.find { |item| item['param_name'] == key }&.[]('example')
      sample ||= examples[index]
      { 'key' => key, 'name' => key, 'component' => 'BODY', 'sample_value' => sample.to_s }
    end
  end

  def failure(error)
    { success: false, error: error }
  end
end

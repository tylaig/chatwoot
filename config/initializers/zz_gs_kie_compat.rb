# frozen_string_literal: true
# Direct official Kie OpenAI compatibility; no forwarding service.
require 'ruby_llm'
module KieDirectCompat
  def kie_direct?
    URI.parse(api_base.to_s).host == 'api.kie.ai'
  end

  def kie_clean(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, item), out|
        out[key] = kie_clean(item) unless %w[strict additionalProperties $schema].include?(key.to_s)
      end
    when Array then value.map { |item| kie_clean(item) }
    else value
    end
  end

  def render_payload(...)
    payload = super
    return payload unless kie_direct?
    payload = kie_clean(payload)
    %i[model temperature response_format stream_options].each { |key| payload.delete(key) }
    @kie_names = {}
    @kie_empty = {}
    Array(payload[:tools]).each_with_index do |tool, index|
      fn = tool[:function] || tool['function']
      original = fn[:name] || fn['name']
      short = "tool_#{index}"
      @kie_names[short] = original
      fn.key?(:name) ? fn[:name] = short : fn['name'] = short
      schema = fn[:parameters] || fn['parameters']
      props = schema && (schema[:properties] || schema['properties'])
      if props && props.empty?
        @kie_empty[short] = true
        props['context'] = { 'type' => 'string', 'description' => 'Optional context' }
      end
    end
    payload[:messages].each do |message|
      message[:role] = 'system' if message[:role] == 'developer'
      message['role'] = 'system' if message['role'] == 'developer'
      Array(message[:tool_calls] || message['tool_calls']).each do |call|
        fn = call[:function] || call['function']
        next unless fn
        name = fn[:name] || fn['name']
        short = @kie_names.key(name) || name
        fn.key?(:name) ? fn[:name] = short : fn['name'] = short
      end
      content = message[:content] || message['content']
      message[:content] = '[Tool call]' if content.nil? || content == ''
    end
    payload
  end

  def sync_response(connection, payload, additional_headers = {})
    return super unless kie_direct?
    payload[:stream] = true
    message = stream_response(connection, payload, additional_headers) { |_chunk| }

    # KIE/Argon can emit a textual function call instead of OpenAI tool_calls.
    # Convert only the exact marker into RubyLLM native ToolCall.
    if !message.tool_call? && message.content.to_s.match?(/Function call requested:\s*tool_\d+/i)
      text = message.content.to_s
      match = text.match(/Function call requested:\s*(tool_\d+)\s*Arguments:\s*(\{.*\})/im)
      if match
        begin
          args = JSON.parse(match[2])
          short = match[1]
          real = @kie_names&.fetch(short, short) || short
          message = RubyLLM::Message.new(
            role: :assistant, content: nil, model_id: message.model_id,
            tool_calls: { short => RubyLLM::ToolCall.new(id: SecureRandom.uuid, name: real, arguments: args) },
            raw: message.raw
          )
        rescue JSON::ParserError
          # Leave malformed output to the normal empty/error handling below.
        end
      end
    end

    raise 'Kie returned no content or tool calls' if message.content.to_s.empty? && !message.tool_call?
    message
  end

  def build_chunk(data)
    return super unless kie_direct?
    if data['code'] && data['code'].to_i != 200
      raise "Kie API error #{data['code']}: #{data['msg']}"
    end
    Array(data.dig('choices', 0, 'delta', 'tool_calls')).each do |call|
      fn = call['function']
      next unless fn && fn['name']
      short = fn['name']
      fn['arguments'] = '{}' if @kie_empty && @kie_empty[short]
      fn['name'] = @kie_names.fetch(short, short) if @kie_names
    end
    super
  end
end
RubyLLM::Providers::OpenAI.prepend(KieDirectCompat)

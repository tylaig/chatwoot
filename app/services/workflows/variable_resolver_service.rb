# frozen_string_literal: true

module Workflows
  class VariableResolverService
    # Suporte tanto a chamada estática com contexto direto quanto instanciada com execution
    def self.resolve(text, context = {})
      resolver = new(nil, context)
      resolver.resolve(text)
    end

    def initialize(execution, custom_context = {})
      @execution = execution
      @account = execution&.account
      @contact = execution&.contact
      @conversation = execution&.conversation
      @inbox = execution&.inbox
      @context = ((execution&.context || {}).merge(custom_context || {})).with_indifferent_access
      @variables = (execution&.variables || {}).with_indifferent_access
    end

    def resolve(text)
      return '' if text.nil?
      return text unless text.is_a?(String)

      text.gsub(/\{\{\s*([a-zA-Z0-9_\.\-]+)\s*\}\}/) do |_match|
        var_path = Regexp.last_match(1)
        val = extract_value(var_path)
        val.nil? ? '' : val.to_s
      end
    end

    def extract_value(path)
      return nil if path.blank?

      parts = path.split('.')
      root = parts.first
      rest = parts[1..]

      case root
      when 'contact'
        resolve_contact(rest)
      when 'conversation'
        resolve_conversation(rest)
      when 'inbox'
        resolve_inbox(rest)
      when 'account'
        resolve_account(rest)
      when 'webhook'
        wb = @context['webhook'] || {}
        pl = wb['payload'] || wb
        val = resolve_hash(pl, rest)
        val = resolve_hash(wb, rest) if val.nil?
        val
      when 'payload', 'trigger'
        pl_data = @context.dig('webhook', 'payload') || @context['payload'] || @context
        resolve_hash(pl_data, rest)
      when 'workflow', 'vars', 'var'
        resolve_hash(@variables, rest) || resolve_hash(@context['workflow'] || {}, rest)
      when 'custom_attributes'
        val = @contact&.custom_attributes&.dig(*rest)
        val = @conversation&.custom_attributes&.dig(*rest) if val.nil?
        val = resolve_hash(@context['custom_attributes'] || {}, rest) if val.nil?
        val
      else
        if @variables.key?(path)
          @variables[path]
        elsif @context.key?(path)
          @context[path]
        else
          resolve_hash(@context, parts)
        end
      end
    end

    private

    def resolve_contact(parts)
      contact_ctx = @contact || @context['contact']
      return nil if contact_ctx.blank? || parts.blank?

      if contact_ctx.is_a?(Hash)
        return resolve_hash(contact_ctx, parts)
      end

      case parts.first
      when 'name' then contact_ctx.name
      when 'first_name' then contact_ctx.name.to_s.split.first
      when 'last_name' then contact_ctx.name.to_s.split[1..].join(' ')
      when 'phone_number', 'phone' then contact_ctx.phone_number
      when 'email' then contact_ctx.email
      when 'id' then contact_ctx.id
      when 'custom_attributes'
        contact_ctx.custom_attributes.is_a?(Hash) ? contact_ctx.custom_attributes.dig(*parts[1..]) : nil
      else
        contact_ctx.respond_to?(parts.first) ? contact_ctx.public_send(parts.first) : nil
      end
    end

    def resolve_conversation(parts)
      conv_ctx = @conversation || @context['conversation']
      return nil if conv_ctx.blank? || parts.blank?

      if conv_ctx.is_a?(Hash)
        return resolve_hash(conv_ctx, parts)
      end

      case parts.first
      when 'id', 'display_id' then conv_ctx.display_id
      when 'status' then conv_ctx.status
      when 'priority' then conv_ctx.priority
      when 'custom_attributes'
        conv_ctx.custom_attributes.is_a?(Hash) ? conv_ctx.custom_attributes.dig(*parts[1..]) : nil
      else
        conv_ctx.respond_to?(parts.first) ? conv_ctx.public_send(parts.first) : nil
      end
    end

    def resolve_inbox(parts)
      inbox_ctx = @inbox || @context['inbox']
      return nil if inbox_ctx.blank? || parts.blank?

      if inbox_ctx.is_a?(Hash)
        return resolve_hash(inbox_ctx, parts)
      end

      case parts.first
      when 'id' then inbox_ctx.id
      when 'name' then inbox_ctx.name
      when 'channel_type' then inbox_ctx.channel_type
      else
        inbox_ctx.respond_to?(parts.first) ? inbox_ctx.public_send(parts.first) : nil
      end
    end

    def resolve_account(parts)
      acc_ctx = @account || @context['account']
      return nil if acc_ctx.blank? || parts.blank?

      if acc_ctx.is_a?(Hash)
        return resolve_hash(acc_ctx, parts)
      end

      case parts.first
      when 'id' then acc_ctx.id
      when 'name' then acc_ctx.name
      else
        acc_ctx.respond_to?(parts.first) ? acc_ctx.public_send(parts.first) : nil
      end
    end

    def resolve_hash(hash, parts)
      return nil if hash.blank? || parts.blank?

      current = hash
      parts.each do |k|
        return nil if current.nil?

        current = if current.is_a?(Array) && k.match?(/^\d+$/)
                    current[k.to_i]
                  elsif current.is_a?(Hash)
                    current[k] || current[k.to_s] || current[k.to_sym]
                  else
                    nil
                  end
      end
      current
    end
  end
end

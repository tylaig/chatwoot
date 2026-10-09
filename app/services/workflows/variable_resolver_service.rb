# frozen_string_literal: true

module Workflows
  class VariableResolverService
    def initialize(execution, custom_context = {})
      @execution = execution
      @account = execution.account
      @contact = execution.contact
      @conversation = execution.conversation
      @inbox = execution.inbox
      @context = (execution.context || {}).merge(custom_context || {})
      @variables = execution.variables || {}
    end

    def resolve(text)
      return '' if text.blank?
      return text unless text.is_a?(String)

      text.gsub(/\{\{\s*([a-zA-Z0-9_\.\-]+)\s*\}\}/) do |_match|
        var_path = Regexp.last_match(1)
        extract_value(var_path).to_s
      end
    end

    def extract_value(path)
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
      when 'webhook', 'payload', 'trigger'
        resolve_hash(@context.dig('webhook', 'payload') || @context['payload'] || @context, rest)
      when 'workflow', 'vars', 'var'
        resolve_hash(@variables, rest)
      when 'custom_attributes'
        @contact&.custom_attributes&.dig(*rest) || @conversation&.custom_attributes&.dig(*rest)
      else
        # Try direct variables or context lookup
        @variables[path] || @context[path] || resolve_hash(@context, parts)
      end
    end

    private

    def resolve_contact(parts)
      return nil if @contact.blank?

      case parts.first
      when 'name' then @contact.name
      when 'first_name' then @contact.name.to_s.split.first
      when 'last_name' then @contact.name.to_s.split[1..].join(' ')
      when 'phone_number', 'phone' then @contact.phone_number
      when 'email' then @contact.email
      when 'id' then @contact.id
      when 'custom_attributes' then @contact.custom_attributes&.dig(*parts[1..])
      else @contact.try(parts.first)
      end
    end

    def resolve_conversation(parts)
      return nil if @conversation.blank?

      case parts.first
      when 'id', 'display_id' then @conversation.display_id
      when 'status' then @conversation.status
      when 'custom_attributes' then @conversation.custom_attributes&.dig(*parts[1..])
      else @conversation.try(parts.first)
      end
    end

    def resolve_inbox(parts)
      return nil if @inbox.blank?

      case parts.first
      when 'id' then @inbox.id
      when 'name' then @inbox.name
      when 'channel_type' then @inbox.channel_type
      else @inbox.try(parts.first)
      end
    end

    def resolve_account(parts)
      case parts.first
      when 'id' then @account.id
      when 'name' then @account.name
      else @account.try(parts.first)
      end
    end

    def resolve_hash(hash, parts)
      return nil if hash.blank? || parts.blank?
      parts.inject(hash) do |acc, k|
        acc.is_a?(Hash) ? (acc[k] || acc[k.to_s] || acc[k.to_sym]) : nil
      end
    end
  end
end

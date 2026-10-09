# frozen_string_literal: true

module Workflows
  class WhatsAppWindowService
    WINDOW_DURATION = 24.hours

    def initialize(conversation)
      @conversation = conversation
    end

    def window_status
      return { open: false, reason: 'conversation_missing' } if @conversation.blank?

      last_msg = last_customer_message
      if last_msg.blank?
        return {
          open: false,
          last_customer_message_at: nil,
          expires_at: nil,
          remaining_seconds: 0,
          reason: 'no_incoming_customer_message'
        }
      end

      expires_at = last_msg.created_at + WINDOW_DURATION
      is_open = Time.current < expires_at
      remaining = [0, (expires_at - Time.current).to_i].max

      {
        open: is_open,
        last_customer_message_at: last_msg.created_at,
        expires_at: expires_at,
        remaining_seconds: remaining,
        reason: is_open ? 'within_24h_window' : 'window_expired'
      }
    end

    def open?
      window_status[:open]
    end

    # Alinhamento direto com o padrão oficial do Chatwoot (Conversations::MessageWindowService)
    def can_reply?
      if @conversation&.inbox&.channel_type.in?(%w[Channel::Whatsapp Channel::TwilioSms])
        Conversations::MessageWindowService.new(@conversation).can_reply?
      else
        open?
      end
    end

    private

    def last_customer_message
      return nil if @conversation.blank?

      # Find the most recent valid incoming message sent by the customer on this conversation
      @conversation.messages
                   .where(account_id: @conversation.account_id)
                   .incoming
                   .where(private: false)
                   .reorder(created_at: :desc)
                   .first
    end
  end
end

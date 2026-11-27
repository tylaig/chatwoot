# Sticky lock set when Captain hands a conversation to humans.
# Prevents the bot from reclaiming the thread if status drifts back to pending
# (common when handoff happens without a human assignee).
class Captain::Conversation::HumanHandoffLock
  LOCK_KEY = 'captain_human_handoff_at'
  REASON_KEY = 'captain_human_handoff_reason'
  CATEGORY_KEY = 'captain_human_handoff_category'

  class << self
    def locked?(conversation)
      conversation.additional_attributes&.dig(LOCK_KEY).present?
    end

    def lock!(conversation, reason: nil, category: nil)
      attrs = (conversation.additional_attributes || {}).merge(
        LOCK_KEY => Time.current.iso8601,
        REASON_KEY => reason.presence,
        CATEGORY_KEY => category.presence
      ).compact
      conversation.update!(additional_attributes: attrs)
    end

    def clear!(conversation)
      return unless locked?(conversation)

      attrs = (conversation.additional_attributes || {}).except(LOCK_KEY, REASON_KEY, CATEGORY_KEY)
      # update_columns avoids nested callbacks when clearing from status-change hooks.
      conversation.update_columns(additional_attributes: attrs, updated_at: Time.current)
    end
  end
end

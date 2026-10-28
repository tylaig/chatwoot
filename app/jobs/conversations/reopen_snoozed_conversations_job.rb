class Conversations::ReopenSnoozedConversationsJob < ApplicationJob
  queue_as :low

  def perform
    Conversation.where(status: :snoozed).where(snoozed_until: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |conversation|
      conversation.check_assignee_team_on_reopen
      conversation.check_assignee_online_on_reopen
      conversation.open!
    end

    redistribute_open_waiting_conversations_with_unavailable_assignees
  end

  private

  def redistribute_open_waiting_conversations_with_unavailable_assignees
    Conversation.open
                .where.not(assignee_id: nil)
                .where.not(waiting_since: nil)
                .where('conversations.last_activity_at >= ?', 24.hours.ago)
                .includes(:inbox, :assignee)
                .find_each(batch_size: 100, &:redistribute_if_assignee_unavailable!)
  end
end

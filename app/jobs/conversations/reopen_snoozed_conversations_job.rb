class Conversations::ReopenSnoozedConversationsJob < ApplicationJob
  queue_as :low

  def perform
    Conversation.where(status: :snoozed).where(snoozed_until: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |conversation|
      conversation.check_assignee_team_on_reopen
      conversation.check_assignee_online_on_reopen
      conversation.open!
    end
  end
end

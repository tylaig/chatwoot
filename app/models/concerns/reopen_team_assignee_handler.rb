# Inbox setting drop_assignee_outside_team_on_reopen: when a customer's message reopens a
# conversation, an assignee who is no longer a member of the conversation's team is
# dropped and the conversation goes back to Unassigned, keeping its team. Every automatic
# picker draws only from the conversation team's members, so none of them can hand it
# back to the agent who was dropped.
#
# Also drops an offline assignee on reopen when inbox auto-assignment is enabled so
# reopened conversations do not remain stuck on an offline agent's queue.
module ReopenTeamAssigneeHandler
  extend ActiveSupport::Concern

  included do
    # Included before AssignmentHandler and AutoAssignmentHandler, so the takeover guard
    # and the legacy auto-assignment in this same save see the owner this settles.
    before_save :drop_assignee_outside_team, if: -> { @reopen_team_check_assignee_id }
    before_save :drop_offline_assignee_on_reopen, if: -> { @reopen_online_check_assignee_id }
  end

  # Called by the customer's message right before the status save that reopens the
  # conversation; the decision is taken inside that save, under the row lock.
  def check_assignee_team_on_reopen
    return unless inbox.drop_assignee_outside_team_on_reopen?

    @reopen_team_check_assignee_id = assignee_id
  end

  def check_assignee_online_on_reopen
    return if assignee_id.blank?
    return unless inbox.enable_auto_assignment?
    return unless inbox.unassign_on_reopen_when_offline? || inbox.unassign_on_reopen_when_busy?

    @reopen_online_check_assignee_id = assignee_id
  end

  # When a customer replies to an already-open conversation whose human assignee is currently
  # offline or busy, drop that assignee and trigger auto-assignment so the customer does not
  # wait on an unavailable agent.
  def redistribute_if_assignee_unavailable!
    return if assignee_id.blank?
    return if assignee_agent_bot_id.present? || ai_assignee_type.present?
    return unless open?
    return unless inbox.enable_auto_assignment?
    return unless inbox.redistribute_open_on_reply_when_offline? || inbox.redistribute_open_on_reply_when_busy?

    online_users = ::OnlineStatusTracker.get_available_users(account_id)
    initial_status = online_users[assignee_id.to_s]
    return if initial_status == 'online'
    return unless should_redistribute_open_for_status?(initial_status)

    judged_id = assignee_id
    unassigned = false

    with_lock do
      next unless open? && assignee_id == judged_id

      current_status = ::OnlineStatusTracker.get_available_users(account_id)[judged_id.to_s]
      next if current_status == 'online'
      next unless should_redistribute_open_for_status?(current_status)

      reason_key = current_status == 'busy' ? 'removed_busy_on_reply' : 'removed_offline_on_reopen'
      @reopen_offline_unassignment = { assignee_name: assignee&.name || '', reason_key: reason_key }
      self.assignee = nil

      if !inbox.auto_assignment_v2_enabled? && should_run_auto_assignment?
        allowed_ids = team_id.present? ? team_member_ids_with_capacity : inbox.member_ids_with_assignment_capacity
        new_assignee = AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: allowed_ids).find_assignee
        self.assignee = new_assignee if new_assignee.present?
      end

      save!
      unassigned = true
    end

    return unless unassigned && inbox.auto_assignment_v2_enabled?

    inbox_id_for_job = inbox.id
    ActiveRecord.after_all_transactions_commit do
      AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox_id_for_job)
    end
  end

  private

  # An agent can reassign, change the team or reopen the conversation after the customer's
  # message read it and before this save. Judging the locked row leaves their action alone:
  # the assignee is dropped only while the row still holds the one judged and is still
  # resolved or snoozed, and only against the team the row holds now.
  def drop_assignee_outside_team
    judged_id = @reopen_team_check_assignee_id
    @reopen_team_check_assignee_id = nil
    @reopen_team_unassignment = nil
    owner_id, persisted_status, persisted_team_id = self.class.lock.where(id: id).pick(:assignee_id, :status, :team_id)
    return unless owner_id == judged_id && %w[resolved snoozed].include?(persisted_status)

    # The legacy auto-assignment later in this save picks from this instance's team, which has
    # to be the one the assignee was judged against.
    self.team_id = persisted_team_id
    clear_attribute_changes([:team_id])
    return if team.blank? || team.team_members.exists?(user_id: judged_id)

    @reopen_team_unassignment = { assignee_name: assignee.name, team_name: team.name }
    self.assignee = nil
  end

  def drop_offline_assignee_on_reopen
    judged_id = @reopen_online_check_assignee_id
    @reopen_online_check_assignee_id = nil
    @reopen_offline_unassignment = nil
    return if assignee_id.blank?

    owner_id, persisted_status, persisted_team_id = self.class.lock.where(id: id).pick(:assignee_id, :status, :team_id)
    return unless owner_id == judged_id && %w[resolved snoozed].include?(persisted_status)

    self.team_id = persisted_team_id
    clear_attribute_changes([:team_id])

    online_users = ::OnlineStatusTracker.get_available_users(account_id)
    current_status = online_users[judged_id.to_s]
    return if current_status == 'online'
    return unless should_unassign_reopen_for_status?(current_status)

    reason_key = current_status == 'busy' ? 'removed_busy_on_reopen' : 'removed_offline_on_reopen'
    @reopen_offline_unassignment = { assignee_name: assignee&.name || '', reason_key: reason_key }
    self.assignee = nil
  end

  def should_unassign_reopen_for_status?(status)
    return inbox.unassign_on_reopen_when_busy? if status == 'busy'

    inbox.unassign_on_reopen_when_offline?
  end

  def should_redistribute_open_for_status?(status)
    return inbox.redistribute_open_on_reply_when_busy? if status == 'busy'

    inbox.redistribute_open_on_reply_when_offline?
  end

  def reopen_team_unassignment?
    @reopen_team_unassignment.present? || @reopen_offline_unassignment.present?
  end

  # Runs with no user and no executed_by (a customer message did it), which would make the
  # generic activity path drop the line; the reason is the point of it anyway.
  def create_reopen_team_unassignment_activity
    if @reopen_team_unassignment.present?
      content = I18n.t('conversations.activity.assignee.removed_not_in_conversation_team', **@reopen_team_unassignment, locale: account.locale)
      @reopen_team_unassignment = nil
    elsif @reopen_offline_unassignment.present?
      key = @reopen_offline_unassignment[:reason_key] || 'removed_offline_on_reopen'
      content = I18n.t("conversations.activity.assignee.#{key}", assignee_name: @reopen_offline_unassignment[:assignee_name], locale: account.locale)
      @reopen_offline_unassignment = nil
    end
    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content)) if content.present?
  end
end

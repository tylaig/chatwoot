class EnforceContactFkOnConversations < ActiveRecord::Migration[7.1]
  def up
    orphan_scope = Conversation.where(contact_id: nil).or(
      Conversation.where('NOT EXISTS (SELECT 1 FROM contacts WHERE contacts.id = conversations.contact_id)')
    )

    count = orphan_scope.count
    raise ActiveRecord::MigrationError, "#{count} conversations have no valid contact; reconcile them before enforcing NOT NULL" if count.positive?

    change_column_null :conversations, :contact_id, false
  end

  def down
    change_column_null :conversations, :contact_id, true
  end
end

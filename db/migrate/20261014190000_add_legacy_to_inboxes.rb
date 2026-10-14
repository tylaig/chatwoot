class AddLegacyToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :legacy, :boolean, default: false, null: false
  end
end

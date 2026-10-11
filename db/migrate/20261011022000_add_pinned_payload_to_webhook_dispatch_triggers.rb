class AddPinnedPayloadToWebhookDispatchTriggers < ActiveRecord::Migration[7.2]
  def change
    add_column :webhook_dispatch_triggers, :pinned_payload, :jsonb, default: {}, null: false
    add_column :webhook_dispatch_triggers, :payload_pinned, :boolean, default: false, null: false
  end
end

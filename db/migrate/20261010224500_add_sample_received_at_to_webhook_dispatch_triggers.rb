class AddSampleReceivedAtToWebhookDispatchTriggers < ActiveRecord::Migration[7.1]
  def change
    add_column :webhook_dispatch_triggers, :sample_received_at, :datetime
  end
end

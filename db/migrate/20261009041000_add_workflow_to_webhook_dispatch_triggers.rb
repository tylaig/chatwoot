class AddWorkflowToWebhookDispatchTriggers < ActiveRecord::Migration[7.1]
  def change
    add_reference :webhook_dispatch_triggers, :workflow, foreign_key: true, index: true, null: true
    add_column :webhook_dispatch_triggers, :dispatch_mode, :string, default: 'template', null: false # 'template' or 'workflow'
  end
end

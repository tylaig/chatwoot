class CreateWebhookDispatchTriggers < ActiveRecord::Migration[7.2]
  def change
    create_table :webhook_dispatch_triggers do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :token, null: false, index: { unique: true }
      t.boolean :active, default: true, null: false
      
      # WhatsApp Template Specs
      t.string :template_name, null: false
      t.string :template_language, default: 'pt_BR', null: false
      
      # Dynamic mapping stored as JSON:
      # {
      #   "phone_path": "customer.phone",
      #   "name_path": "customer.name",
      #   "parameters": [
      #     { "type": "path", "value": "order.first_name" },
      #     { "type": "path", "value": "order.amount" },
      #     { "type": "static", "value": "Meu Super App" }
      #   ],
      #   "labels": ["pos-venda", "webhook-disparo"]
      # }
      t.jsonb :field_mapping, default: {}, null: false
      t.jsonb :sample_payload, default: {}, null: false
      
      t.timestamps
    end
  end
end

class CreateWhatsappTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_templates do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, foreign_key: true, index: true, null: true
      t.string :name, null: false
      t.string :category, default: 'MARKETING_LITE', null: false
      t.string :language, default: 'pt_BR', null: false
      t.string :status, default: 'APPROVED', null: false
      t.string :header_type, default: 'NONE'
      t.text :header_content
      t.text :body, null: false
      t.string :footer
      t.jsonb :buttons, default: []
      t.jsonb :variables, default: []
      t.string :meta_template_id
      t.string :rejection_reason

      t.timestamps
    end

    add_index :whatsapp_templates, [:account_id, :name, :language], unique: true, name: 'index_whatsapp_templates_on_account_name_lang'
  end
end

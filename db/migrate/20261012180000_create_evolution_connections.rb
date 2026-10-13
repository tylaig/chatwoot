class CreateEvolutionConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :evolution_connections do |t|
      t.bigint :account_id, null: false
      t.string :base_url, null: false
      t.text :api_key
      t.string :version
      t.string :client_name
      t.string :status, null: false, default: 'disconnected'
      t.integer :instance_count, null: false, default: 0
      t.datetime :last_checked_at
      t.text :last_error
      t.timestamps
    end

    add_index :evolution_connections, :account_id, unique: true
  end
end

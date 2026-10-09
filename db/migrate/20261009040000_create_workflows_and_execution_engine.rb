class CreateWorkflowsAndExecutionEngine < ActiveRecord::Migration[7.1]
  def change
    create_table :workflows do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'draft', null: false # draft, active, paused, archived
      t.string :trigger_type, default: 'webhook', null: false
      t.integer :active_version_id
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.jsonb :settings, default: {}, null: false

      t.timestamps
    end

    create_table :workflow_versions do |t|
      t.references :workflow, null: false, foreign_key: true, index: true
      t.integer :version_number, null: false
      t.string :status, default: 'draft', null: false # draft, published, archived
      t.jsonb :nodes, default: [], null: false
      t.jsonb :edges, default: [], null: false
      t.jsonb :viewport, default: { x: 0, y: 0, zoom: 1 }, null: false
      t.string :change_summary

      t.timestamps
    end

    add_index :workflow_versions, [:workflow_id, :version_number], unique: true

    create_table :workflow_executions do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :workflow, null: false, foreign_key: true, index: true
      t.references :workflow_version, null: false, foreign_key: true, index: true
      t.references :contact, foreign_key: true, index: true, null: true
      t.references :conversation, foreign_key: true, index: true, null: true
      t.references :inbox, foreign_key: true, index: true, null: true
      t.string :trigger_type, null: false
      t.string :idempotency_key, index: true
      t.string :status, default: 'running', null: false # running, waiting, completed, failed, cancelled
      t.string :current_node_id
      t.jsonb :context, default: {}, null: false
      t.jsonb :variables, default: {}, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end

    create_table :workflow_node_executions do |t|
      t.references :workflow_execution, null: false, foreign_key: true, index: true
      t.string :node_id, null: false
      t.string :node_type, null: false
      t.string :status, default: 'running', null: false # running, success, failed, skipped, waiting
      t.jsonb :input_data, default: {}
      t.jsonb :output_data, default: {}
      t.text :error_message
      t.integer :duration_ms, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    create_table :workflow_wait_states do |t|
      t.references :workflow_execution, null: false, foreign_key: true, index: true
      t.string :node_id, null: false
      t.string :wait_type, null: false # delay, wait_for_reply, wait_until
      t.datetime :resume_at
      t.datetime :timeout_at
      t.string :status, default: 'pending', null: false # pending, resumed, timed_out, cancelled
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :workflow_wait_states, [:status, :resume_at]
    add_index :workflow_wait_states, [:status, :timeout_at]
  end
end

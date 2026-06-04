class CreateAdminModelRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_model_requests do |t|
      t.integer :workspace_id, null: false
      t.integer :user_id, null: false
      t.string :status, null: false, default: "queued"
      t.string :runtime, null: false
      t.string :model, null: false
      t.string :base_url, null: false
      t.integer :timeout_seconds, null: false, default: 120
      t.text :system_prompt, null: false
      t.text :prompt, null: false
      t.text :answer
      t.json :answer_json
      t.json :response_json
      t.text :error_message
      t.integer :duration_ms
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :admin_model_requests, :workspace_id
    add_index :admin_model_requests, :user_id
    add_index :admin_model_requests, [ :workspace_id, :user_id, :created_at ]
    add_index :admin_model_requests, :status
  end
end

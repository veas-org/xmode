class CreateCodeModelProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :code_model_profiles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :base_url, null: false
      t.text :api_key_ciphertext
      t.integer :timeout_seconds, default: 3600, null: false
      t.float :temperature, default: 0.2, null: false
      t.integer :max_tokens, default: 1024, null: false
      t.integer :context_window, default: 4096, null: false
      t.string :status, default: "active", null: false
      t.boolean :default_profile, default: false, null: false
      t.json :metadata, default: {}, null: false
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :code_model_profiles, [ :workspace_id, :provider, :name ], unique: true
    add_index :code_model_profiles, [ :workspace_id, :default_profile ]
    add_index :code_model_profiles, [ :workspace_id, :status ]

    add_reference :admin_model_requests, :code_model_profile, foreign_key: true
    add_column :admin_model_requests, :request_options, :json, default: {}, null: false
  end
end

class CreateCodexSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :codex_sessions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :project, foreign_key: true
      t.references :pipeline_run, foreign_key: true
      t.references :sandbox_session, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :runtime, null: false, default: "cloud_subscription"
      t.string :model, null: false, default: "codex-cloud"
      t.string :title, null: false
      t.text :objective, null: false
      t.string :cloud_environment_id
      t.string :cloud_task_id
      t.string :branch
      t.string :working_directory
      t.string :sandbox_mode, null: false, default: "workspace-write"
      t.string :approval_policy, null: false, default: "never"
      t.json :metadata, null: false, default: {}
      t.text :last_error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :codex_sessions, [ :workspace_id, :created_at ]
    add_index :codex_sessions, [ :workspace_id, :status ]
    add_index :codex_sessions, :cloud_task_id
    add_index :codex_sessions, :cloud_environment_id

    create_table :codex_session_messages do |t|
      t.references :codex_session, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :role, null: false, default: "user"
      t.string :status, null: false, default: "queued"
      t.text :content, null: false
      t.text :response
      t.json :metadata, null: false, default: {}
      t.integer :duration_ms
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :codex_session_messages, [ :codex_session_id, :created_at ], name: "index_codex_messages_on_session_created_at"
    add_index :codex_session_messages, [ :codex_session_id, :status ], name: "index_codex_messages_on_session_status"
  end
end

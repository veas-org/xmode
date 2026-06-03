class AddStructuredRunChatAndSandboxes < ActiveRecord::Migration[8.0]
  def change
    create_table :run_messages do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.references :user, foreign_key: true
      t.string :role, null: false
      t.string :kind, null: false, default: "text"
      t.string :status, null: false, default: "resolved"
      t.text :content
      t.json :payload, null: false, default: {}
      t.datetime :answered_at
      t.timestamps
    end

    add_index :run_messages, [ :pipeline_run_id, :status ]
    add_index :run_messages, [ :pipeline_run_id, :created_at ]

    create_table :sandbox_sessions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.string :kind, null: false, default: "docker_worktree"
      t.string :status, null: false, default: "provisioning"
      t.string :worktree_path
      t.string :container_id
      t.string :browser_session_id
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :expires_at
      t.json :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :sandbox_sessions, [ :pipeline_run_id, :status ]
    add_index :sandbox_sessions, [ :action_run_step_id, :kind ]
  end
end

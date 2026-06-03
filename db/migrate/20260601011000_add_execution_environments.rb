class AddExecutionEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :execution_environments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.string :kind, null: false, default: "ephemeral_sandbox"
      t.string :status, null: false, default: "ready"
      t.string :name, null: false
      t.json :metadata, null: false, default: {}
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :execution_environments, [ :workspace_id, :project_id, :kind, :name ], unique: true
    add_reference :sandbox_sessions, :execution_environment, foreign_key: true
  end
end

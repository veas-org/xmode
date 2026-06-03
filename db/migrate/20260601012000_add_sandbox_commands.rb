class AddSandboxCommands < ActiveRecord::Migration[8.0]
  def change
    create_table :sandbox_commands do |t|
      t.references :sandbox_session, null: false, foreign_key: true
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.references :user, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.text :command, null: false
      t.text :stdout
      t.text :stderr
      t.integer :exit_status
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :sandbox_commands, [ :sandbox_session_id, :created_at ]
    add_index :sandbox_commands, [ :pipeline_run_id, :status ]
  end
end

class CreateAgentSwarmRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_swarm_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :agent_swarm_definition, foreign_key: true
      t.references :user, foreign_key: true
      t.references :project, foreign_key: true
      t.references :issue, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :trigger, null: false, default: "manual"
      t.text :objective
      t.json :swarm_snapshot, null: false, default: {}
      t.json :member_results, null: false, default: []
      t.text :result_summary
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :agent_swarm_runs, [ :workspace_id, :status, :created_at ]
    add_index :agent_swarm_runs, [ :workspace_id, :agent_swarm_definition_id, :created_at ], name: "index_swarm_runs_on_workspace_definition_created_at"
  end
end

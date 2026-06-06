class CreateAgentDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_definitions do |t|
      t.references :workspace, foreign_key: true
      t.references :parent_agent_definition, foreign_key: { to_table: :agent_definitions }
      t.string :key, null: false
      t.string :name, null: false
      t.string :version, null: false, default: "1.0.0"
      t.string :category, null: false
      t.string :runtime, null: false, default: "model"
      t.string :model
      t.text :description
      t.text :system_prompt
      t.text :system_prompt_append
      t.json :tools, null: false, default: []
      t.json :settings, null: false, default: {}
      t.json :metadata, null: false, default: {}
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end
    add_index :agent_definitions, [ :workspace_id, :key, :version ], unique: true, name: "index_agent_definitions_on_workspace_key_version"

    add_reference :action_definitions, :agent_definition, foreign_key: true

    create_table :agent_swarm_definitions do |t|
      t.references :workspace, foreign_key: true
      t.references :coordinator_agent_definition, foreign_key: { to_table: :agent_definitions }
      t.string :key, null: false
      t.string :name, null: false
      t.string :version, null: false, default: "1.0.0"
      t.string :category, null: false
      t.string :strategy, null: false, default: "coordinated"
      t.text :description
      t.text :coordination_prompt
      t.json :metadata, null: false, default: {}
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end
    add_index :agent_swarm_definitions, [ :workspace_id, :key, :version ], unique: true, name: "index_agent_swarms_on_workspace_key_version"

    create_table :agent_swarm_memberships do |t|
      t.references :agent_swarm_definition, null: false, foreign_key: true
      t.references :agent_definition, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.integer :position, null: false, default: 0
      t.text :instructions_append
      t.json :settings, null: false, default: {}
      t.timestamps
    end
    add_index :agent_swarm_memberships, [ :agent_swarm_definition_id, :agent_definition_id, :role ], unique: true, name: "index_agent_swarm_memberships_on_swarm_agent_role"
  end
end

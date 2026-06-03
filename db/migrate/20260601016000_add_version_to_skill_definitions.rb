class AddVersionToSkillDefinitions < ActiveRecord::Migration[8.0]
  def change
    add_column :skill_definitions, :version, :string, null: false, default: "1.0.0"
    remove_index :skill_definitions, column: [ :workspace_id, :key ], if_exists: true
    add_index :skill_definitions, [ :workspace_id, :key, :version ], unique: true, name: "index_skill_definitions_on_workspace_key_version"
  end
end

class AddSkillManagement < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_definitions do |t|
      t.references :workspace, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :category, null: false
      t.text :description
      t.text :instructions
      t.text :objective_template
      t.text :plan_template
      t.json :input_schema, null: false, default: {}
      t.json :output_schema, null: false, default: {}
      t.json :best_practices, null: false, default: []
      t.json :metadata, null: false, default: {}
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end
    add_index :skill_definitions, [ :workspace_id, :key ], unique: true

    add_reference :action_definitions, :skill_definition, foreign_key: true
    add_column :action_definitions, :requires_objective, :boolean, null: false, default: true
    add_column :action_definitions, :plan_required_when_objective_unclear, :boolean, null: false, default: true
    add_column :action_definitions, :objective_template, :text
    add_column :action_definitions, :plan_template, :text
    add_column :action_definitions, :execution_guidance, :text
    add_column :action_definitions, :best_practices, :json, null: false, default: []
  end
end

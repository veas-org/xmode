class AddCatalogVersionControl < ActiveRecord::Migration[8.0]
  def change
    add_column :action_definitions, :version, :string, null: false, default: "1.0.0"
    remove_index :action_definitions, name: "index_action_definitions_on_workspace_id_and_key", if_exists: true
    add_index :action_definitions, [ :workspace_id, :key, :version ], unique: true, name: "index_action_definitions_on_workspace_key_version"

    add_column :pipeline_definitions, :version, :string, null: false, default: "1.0.0"
    remove_index :pipeline_definitions, name: "index_pipeline_definitions_on_workspace_id_and_key", if_exists: true
    add_index :pipeline_definitions, [ :workspace_id, :key, :version ], unique: true, name: "index_pipeline_definitions_on_workspace_key_version"

    create_table :catalog_versions do |t|
      t.integer :workspace_id
      t.string :versionable_type, null: false
      t.integer :versionable_id, null: false
      t.string :key, null: false
      t.string :version, null: false
      t.integer :revision, null: false, default: 1
      t.string :source, null: false, default: "app"
      t.integer :created_by_id
      t.json :snapshot, null: false, default: {}
      t.timestamps
    end

    add_index :catalog_versions, [ :versionable_type, :versionable_id ], name: "index_catalog_versions_on_versionable"
    add_index :catalog_versions, [ :versionable_type, :versionable_id, :version, :revision ], unique: true, name: "index_catalog_versions_on_record_version_revision"
    add_index :catalog_versions, [ :workspace_id, :versionable_type, :key, :version ], name: "index_catalog_versions_on_workspace_catalog_key"
    add_index :catalog_versions, :created_by_id
  end
end

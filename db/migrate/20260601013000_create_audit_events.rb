class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :auditable_type
      t.bigint :auditable_id
      t.string :action, null: false
      t.string :severity, null: false, default: "info"
      t.string :source, null: false, default: "app"
      t.string :ip_address
      t.string :user_agent
      t.json :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :audit_events, [ :auditable_type, :auditable_id ]
    add_index :audit_events, [ :workspace_id, :created_at ]
    add_index :audit_events, [ :workspace_id, :action ]
  end
end

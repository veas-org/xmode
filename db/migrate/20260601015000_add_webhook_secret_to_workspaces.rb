class AddWebhookSecretToWorkspaces < ActiveRecord::Migration[8.0]
  def up
    add_column :workspaces, :webhook_secret, :string

    workspace_class = Class.new(ActiveRecord::Base) do
      self.table_name = "workspaces"
    end
    workspace_class.reset_column_information
    workspace_class.find_each do |workspace|
      workspace.update_columns(webhook_secret: SecureRandom.hex(32))
    end

    change_column_null :workspaces, :webhook_secret, false
    add_index :workspaces, :webhook_secret, unique: true
  end

  def down
    remove_index :workspaces, :webhook_secret
    remove_column :workspaces, :webhook_secret
  end
end

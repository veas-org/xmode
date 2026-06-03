class RenameSsoDefaultRole < ActiveRecord::Migration[8.0]
  def change
    rename_column :sso_providers, :default_role, :default_membership_role
  end
end

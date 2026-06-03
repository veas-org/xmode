class AddSsoIdentityProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :sso_providers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :provider_type, null: false, default: "oidc"
      t.string :status, null: false, default: "active"
      t.string :issuer
      t.string :authorization_endpoint
      t.string :token_endpoint
      t.string :userinfo_endpoint
      t.string :client_id
      t.string :client_secret_ciphertext
      t.string :scopes, null: false, default: "openid email profile"
      t.string :email_domain
      t.boolean :allow_signups, null: false, default: true
      t.string :default_role, null: false, default: "member"
      t.json :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :sso_providers, [ :workspace_id, :name ], unique: true

    create_table :sso_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sso_provider, null: false, foreign_key: true
      t.string :provider_uid, null: false
      t.string :email, null: false, default: ""
      t.string :name, null: false, default: ""
      t.json :raw_info, null: false, default: {}
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :sso_identities, [ :sso_provider_id, :provider_uid ], unique: true
    add_index :sso_identities, [ :sso_provider_id, :email ]
  end
end

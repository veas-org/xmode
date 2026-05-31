class CreateXmodeCore < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false, default: ""
      t.string :email, null: false
      t.string :password_digest
      t.string :theme_preference, null: false, default: "system"
      t.datetime :last_sign_in_at
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :billing_plan, null: false, default: "community"
      t.string :stripe_customer_id
      t.timestamps
    end
    add_index :workspaces, :slug, unique: true

    create_table :teams do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.timestamps
    end
    add_index :teams, [ :workspace_id, :key ], unique: true

    create_table :memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :memberships, [ :workspace_id, :team_id, :user_id ], unique: true

    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :invitations, :token, unique: true

    create_table :projects do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :title, null: false
      t.string :key, null: false
      t.text :description
      t.string :status, null: false, default: "planned"
      t.string :repository_url
      t.timestamps
    end
    add_index :projects, [ :workspace_id, :key ], unique: true

    create_table :cycles do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.date :starts_on
      t.date :ends_on
      t.string :status, null: false, default: "planned"
      t.timestamps
    end

    create_table :issue_statuses do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false, default: "backlog"
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :issues do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.references :cycle, foreign_key: true
      t.references :issue_status, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :parent, foreign_key: { to_table: :issues }
      t.string :identifier, null: false
      t.string :title, null: false
      t.text :description
      t.string :priority, null: false, default: "medium"
      t.integer :estimate
      t.date :due_on
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :issues, [ :workspace_id, :identifier ], unique: true

    create_table :labels do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "#71717a"
      t.timestamps
    end

    create_table :issue_labels do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.timestamps
    end
    add_index :issue_labels, [ :issue_id, :label_id ], unique: true

    create_table :issue_relations do |t|
      t.references :source_issue, null: false, foreign_key: { to_table: :issues }
      t.references :target_issue, null: false, foreign_key: { to_table: :issues }
      t.string :relation_type, null: false
      t.timestamps
    end

    create_table :objectives do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :objectiveable, polymorphic: true
      t.string :title, null: false
      t.text :body
      t.timestamps
    end

    create_table :plan_records do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :plannable, polymorphic: true
      t.string :title, null: false
      t.text :body
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    create_table :goals do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :goalable, polymorphic: true
      t.string :title, null: false
      t.string :metric
      t.string :target_value
      t.string :current_value
      t.string :status, null: false, default: "open"
      t.timestamps
    end

    create_table :events do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.references :issue, foreign_key: true
      t.string :source, null: false
      t.string :event_type, null: false, default: "generic"
      t.string :title, null: false
      t.string :severity, null: false, default: "info"
      t.string :status, null: false, default: "new"
      t.json :payload, null: false, default: {}
      t.json :normalized, null: false, default: {}
      t.timestamps
    end

    create_table :event_rules do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline_definition
      t.string :name, null: false
      t.string :source
      t.string :event_type
      t.json :conditions, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :action_definitions do |t|
      t.references :workspace, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :category, null: false
      t.string :provider, null: false, default: "manual"
      t.json :permissions, null: false, default: []
      t.json :input_schema, null: false, default: {}
      t.json :output_schema, null: false, default: {}
      t.json :defaults, null: false, default: {}
      t.json :runtime_config, null: false, default: {}
      t.integer :timeout_seconds, null: false, default: 600
      t.json :retry_policy, null: false, default: {}
      t.json :artifact_policy, null: false, default: {}
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end
    add_index :action_definitions, [ :workspace_id, :key ], unique: true

    create_table :pipeline_definitions do |t|
      t.references :workspace, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false
      t.json :required_context, null: false, default: {}
      t.json :graph, null: false, default: { nodes: [], edges: [] }
      t.json :triggers, null: false, default: []
      t.json :permissions, null: false, default: []
      t.boolean :builtin, null: false, default: false
      t.timestamps
    end
    add_index :pipeline_definitions, [ :workspace_id, :key ], unique: true

    create_table :pipeline_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline_definition, foreign_key: true
      t.references :user, foreign_key: true
      t.references :project, foreign_key: true
      t.references :issue, foreign_key: true
      t.references :event, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :trigger, null: false, default: "manual"
      t.json :input_context, null: false, default: {}
      t.json :pipeline_snapshot, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.timestamps
    end

    create_table :action_run_steps do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_definition, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "queued"
      t.integer :position, null: false, default: 0
      t.json :input_json, null: false, default: {}
      t.json :output_json, null: false, default: {}
      t.json :action_snapshot, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.timestamps
    end

    create_table :run_logs do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.string :level, null: false, default: "info"
      t.text :message, null: false
      t.timestamps
    end

    create_table :run_artifacts do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.string :name, null: false
      t.string :path, null: false
      t.string :content_type
      t.integer :byte_size
      t.timestamps
    end

    create_table :approvals do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :action_run_step, foreign_key: true
      t.references :user, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :decision
      t.text :notes
      t.timestamps
    end

    create_table :schedules do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :pipeline_definition, null: false, foreign_key: true
      t.references :schedulable, polymorphic: true
      t.string :kind, null: false
      t.datetime :run_at
      t.string :cron
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :integration_accounts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :name, null: false
      t.text :token_ciphertext
      t.json :metadata, null: false, default: {}
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :repository_connections do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :integration_account, foreign_key: true
      t.string :provider, null: false
      t.string :name, null: false
      t.string :full_name
      t.string :url, null: false
      t.string :default_branch, null: false, default: "main"
      t.string :external_id
      t.timestamps
    end

    create_table :change_requests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :repository_connection, null: false, foreign_key: true
      t.references :pipeline_run, foreign_key: true
      t.references :issue, foreign_key: true
      t.string :provider, null: false
      t.string :external_id
      t.string :branch_name, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.string :url
      t.json :checks, null: false, default: {}
      t.timestamps
    end

    create_table :billing_subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :plan, null: false, default: "community"
      t.string :status, null: false, default: "inactive"
      t.string :stripe_subscription_id
      t.datetime :current_period_end
      t.integer :seats, null: false, default: 1
      t.integer :automation_minutes_used, null: false, default: 0
      t.timestamps
    end

    create_table :saved_views do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :view_type, null: false
      t.json :filters, null: false, default: {}
      t.timestamps
    end
  end
end

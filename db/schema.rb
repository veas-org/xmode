# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_06_020000) do
  create_table "action_definitions", force: :cascade do |t|
    t.integer "workspace_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "provider", default: "manual", null: false
    t.json "permissions", default: [], null: false
    t.json "input_schema", default: {}, null: false
    t.json "output_schema", default: {}, null: false
    t.json "defaults", default: {}, null: false
    t.json "runtime_config", default: {}, null: false
    t.integer "timeout_seconds", default: 600, null: false
    t.json "retry_policy", default: {}, null: false
    t.json "artifact_policy", default: {}, null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "skill_definition_id"
    t.boolean "requires_objective", default: true, null: false
    t.boolean "plan_required_when_objective_unclear", default: true, null: false
    t.text "objective_template"
    t.text "plan_template"
    t.text "execution_guidance"
    t.json "best_practices", default: [], null: false
    t.string "version", default: "1.0.0", null: false
    t.integer "agent_definition_id"
    t.index ["agent_definition_id"], name: "index_action_definitions_on_agent_definition_id"
    t.index ["skill_definition_id"], name: "index_action_definitions_on_skill_definition_id"
    t.index ["workspace_id", "key", "version"], name: "index_action_definitions_on_workspace_key_version", unique: true
    t.index ["workspace_id"], name: "index_action_definitions_on_workspace_id"
  end

  create_table "action_run_steps", force: :cascade do |t|
    t.integer "pipeline_run_id", null: false
    t.integer "action_definition_id"
    t.string "name", null: false
    t.string "status", default: "queued", null: false
    t.integer "position", default: 0, null: false
    t.json "input_json", default: {}, null: false
    t.json "output_json", default: {}, null: false
    t.json "action_snapshot", default: {}, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_definition_id"], name: "index_action_run_steps_on_action_definition_id"
    t.index ["pipeline_run_id"], name: "index_action_run_steps_on_pipeline_run_id"
  end

  create_table "admin_model_requests", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "user_id", null: false
    t.string "status", default: "queued", null: false
    t.string "runtime", null: false
    t.string "model", null: false
    t.string "base_url", null: false
    t.integer "timeout_seconds", default: 120, null: false
    t.text "system_prompt", null: false
    t.text "prompt", null: false
    t.text "answer"
    t.json "answer_json"
    t.json "response_json"
    t.text "error_message"
    t.integer "duration_ms"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "code_model_profile_id"
    t.json "request_options", default: {}, null: false
    t.index ["code_model_profile_id"], name: "index_admin_model_requests_on_code_model_profile_id"
    t.index ["status"], name: "index_admin_model_requests_on_status"
    t.index ["user_id"], name: "index_admin_model_requests_on_user_id"
    t.index ["workspace_id", "user_id", "created_at"], name: "idx_on_workspace_id_user_id_created_at_6d04e7b74a"
    t.index ["workspace_id"], name: "index_admin_model_requests_on_workspace_id"
  end

  create_table "agent_definitions", force: :cascade do |t|
    t.integer "workspace_id"
    t.integer "parent_agent_definition_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "version", default: "1.0.0", null: false
    t.string "category", null: false
    t.string "runtime", default: "model", null: false
    t.string "model"
    t.text "description"
    t.text "system_prompt"
    t.text "system_prompt_append"
    t.json "tools", default: [], null: false
    t.json "settings", default: {}, null: false
    t.json "metadata", default: {}, null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_agent_definition_id"], name: "index_agent_definitions_on_parent_agent_definition_id"
    t.index ["workspace_id", "key", "version"], name: "index_agent_definitions_on_workspace_key_version", unique: true
    t.index ["workspace_id"], name: "index_agent_definitions_on_workspace_id"
  end

  create_table "agent_swarm_definitions", force: :cascade do |t|
    t.integer "workspace_id"
    t.integer "coordinator_agent_definition_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "version", default: "1.0.0", null: false
    t.string "category", null: false
    t.string "strategy", default: "coordinated", null: false
    t.text "description"
    t.text "coordination_prompt"
    t.json "metadata", default: {}, null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coordinator_agent_definition_id"], name: "idx_on_coordinator_agent_definition_id_8d2d16830d"
    t.index ["workspace_id", "key", "version"], name: "index_agent_swarms_on_workspace_key_version", unique: true
    t.index ["workspace_id"], name: "index_agent_swarm_definitions_on_workspace_id"
  end

  create_table "agent_swarm_memberships", force: :cascade do |t|
    t.integer "agent_swarm_definition_id", null: false
    t.integer "agent_definition_id", null: false
    t.string "role", default: "member", null: false
    t.integer "position", default: 0, null: false
    t.text "instructions_append"
    t.json "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_definition_id"], name: "index_agent_swarm_memberships_on_agent_definition_id"
    t.index ["agent_swarm_definition_id", "agent_definition_id", "role"], name: "index_agent_swarm_memberships_on_swarm_agent_role", unique: true
    t.index ["agent_swarm_definition_id"], name: "index_agent_swarm_memberships_on_agent_swarm_definition_id"
  end

  create_table "approvals", force: :cascade do |t|
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.integer "user_id"
    t.string "status", default: "pending", null: false
    t.string "decision"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_run_step_id"], name: "index_approvals_on_action_run_step_id"
    t.index ["pipeline_run_id"], name: "index_approvals_on_pipeline_run_id"
    t.index ["user_id"], name: "index_approvals_on_user_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "user_id"
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.string "action", null: false
    t.string "severity", default: "info", null: false
    t.string "source", default: "app", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
    t.index ["workspace_id", "action"], name: "index_audit_events_on_workspace_id_and_action"
    t.index ["workspace_id", "created_at"], name: "index_audit_events_on_workspace_id_and_created_at"
    t.index ["workspace_id"], name: "index_audit_events_on_workspace_id"
  end

  create_table "automation_runs", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "execution_type", null: false
    t.integer "execution_id", null: false
    t.string "kind", default: "pipeline", null: false
    t.string "status", default: "queued", null: false
    t.string "trigger", default: "manual", null: false
    t.string "title", null: false
    t.string "target_label"
    t.text "objective"
    t.json "metadata", default: {}, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_type", "execution_id"], name: "index_automation_runs_on_execution_type_and_execution_id", unique: true
    t.index ["workspace_id", "kind", "created_at"], name: "index_automation_runs_on_workspace_id_and_kind_and_created_at"
    t.index ["workspace_id", "status", "created_at"], name: "idx_on_workspace_id_status_created_at_a75f129314"
    t.index ["workspace_id"], name: "index_automation_runs_on_workspace_id"
  end

  create_table "billing_subscriptions", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "plan", default: "community", null: false
    t.string "status", default: "inactive", null: false
    t.string "stripe_subscription_id"
    t.datetime "current_period_end"
    t.integer "seats", default: 1, null: false
    t.integer "automation_minutes_used", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_billing_subscriptions_on_workspace_id"
  end

  create_table "catalog_versions", force: :cascade do |t|
    t.integer "workspace_id"
    t.string "versionable_type", null: false
    t.integer "versionable_id", null: false
    t.string "key", null: false
    t.string "version", null: false
    t.integer "revision", default: 1, null: false
    t.string "source", default: "app", null: false
    t.integer "created_by_id"
    t.json "snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_catalog_versions_on_created_by_id"
    t.index ["versionable_type", "versionable_id", "version", "revision"], name: "index_catalog_versions_on_record_version_revision", unique: true
    t.index ["versionable_type", "versionable_id"], name: "index_catalog_versions_on_versionable"
    t.index ["workspace_id", "versionable_type", "key", "version"], name: "index_catalog_versions_on_workspace_catalog_key"
  end

  create_table "change_requests", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "repository_connection_id", null: false
    t.integer "pipeline_run_id"
    t.integer "issue_id"
    t.string "provider", null: false
    t.string "external_id"
    t.string "branch_name", null: false
    t.string "title", null: false
    t.string "status", default: "draft", null: false
    t.string "url"
    t.json "checks", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id"], name: "index_change_requests_on_issue_id"
    t.index ["pipeline_run_id"], name: "index_change_requests_on_pipeline_run_id"
    t.index ["repository_connection_id"], name: "index_change_requests_on_repository_connection_id"
    t.index ["workspace_id"], name: "index_change_requests_on_workspace_id"
  end

  create_table "code_model_profiles", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "base_url", null: false
    t.text "api_key_ciphertext"
    t.integer "timeout_seconds", default: 3600, null: false
    t.float "temperature", default: 0.2, null: false
    t.integer "max_tokens", default: 1024, null: false
    t.integer "context_window", default: 4096, null: false
    t.string "status", default: "active", null: false
    t.boolean "default_profile", default: false, null: false
    t.json "metadata", default: {}, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "default_profile"], name: "index_code_model_profiles_on_workspace_id_and_default_profile"
    t.index ["workspace_id", "provider", "name"], name: "idx_on_workspace_id_provider_name_1b3eec67d8", unique: true
    t.index ["workspace_id", "status"], name: "index_code_model_profiles_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_code_model_profiles_on_workspace_id"
  end

  create_table "codex_session_messages", force: :cascade do |t|
    t.integer "codex_session_id", null: false
    t.integer "user_id"
    t.string "role", default: "user", null: false
    t.string "status", default: "queued", null: false
    t.text "content", null: false
    t.text "response"
    t.json "metadata", default: {}, null: false
    t.integer "duration_ms"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["codex_session_id", "created_at"], name: "index_codex_messages_on_session_created_at"
    t.index ["codex_session_id", "status"], name: "index_codex_messages_on_session_status"
    t.index ["codex_session_id"], name: "index_codex_session_messages_on_codex_session_id"
    t.index ["user_id"], name: "index_codex_session_messages_on_user_id"
  end

  create_table "codex_sessions", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "user_id"
    t.integer "project_id"
    t.integer "pipeline_run_id"
    t.integer "sandbox_session_id"
    t.string "status", default: "queued", null: false
    t.string "runtime", default: "cloud_subscription", null: false
    t.string "model", default: "codex-cloud", null: false
    t.string "title", null: false
    t.text "objective", null: false
    t.string "cloud_environment_id"
    t.string "cloud_task_id"
    t.string "branch"
    t.string "working_directory"
    t.string "sandbox_mode", default: "workspace-write", null: false
    t.string "approval_policy", default: "never", null: false
    t.json "metadata", default: {}, null: false
    t.text "last_error"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cloud_environment_id"], name: "index_codex_sessions_on_cloud_environment_id"
    t.index ["cloud_task_id"], name: "index_codex_sessions_on_cloud_task_id"
    t.index ["pipeline_run_id"], name: "index_codex_sessions_on_pipeline_run_id"
    t.index ["project_id"], name: "index_codex_sessions_on_project_id"
    t.index ["sandbox_session_id"], name: "index_codex_sessions_on_sandbox_session_id"
    t.index ["user_id"], name: "index_codex_sessions_on_user_id"
    t.index ["workspace_id", "created_at"], name: "index_codex_sessions_on_workspace_id_and_created_at"
    t.index ["workspace_id", "status"], name: "index_codex_sessions_on_workspace_id_and_status"
    t.index ["workspace_id"], name: "index_codex_sessions_on_workspace_id"
  end

  create_table "cycles", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id", null: false
    t.string "name", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.string "status", default: "planned", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_cycles_on_team_id"
    t.index ["workspace_id"], name: "index_cycles_on_workspace_id"
  end

  create_table "event_rules", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "pipeline_definition_id"
    t.string "name", null: false
    t.string "source"
    t.string "event_type"
    t.json "conditions", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_definition_id"], name: "index_event_rules_on_pipeline_definition_id"
    t.index ["workspace_id"], name: "index_event_rules_on_workspace_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "project_id"
    t.integer "issue_id"
    t.string "source", null: false
    t.string "event_type", default: "generic", null: false
    t.string "title", null: false
    t.string "severity", default: "info", null: false
    t.string "status", default: "new", null: false
    t.json "payload", default: {}, null: false
    t.json "normalized", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id"], name: "index_events_on_issue_id"
    t.index ["project_id"], name: "index_events_on_project_id"
    t.index ["workspace_id"], name: "index_events_on_workspace_id"
  end

  create_table "execution_environments", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "project_id"
    t.string "kind", default: "ephemeral_sandbox", null: false
    t.string "status", default: "ready", null: false
    t.string "name", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_execution_environments_on_project_id"
    t.index ["workspace_id", "project_id", "kind", "name"], name: "idx_on_workspace_id_project_id_kind_name_ce578388cf", unique: true
    t.index ["workspace_id"], name: "index_execution_environments_on_workspace_id"
  end

  create_table "goals", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "goalable_type"
    t.integer "goalable_id"
    t.string "title", null: false
    t.string "metric"
    t.string "target_value"
    t.string "current_value"
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goalable_type", "goalable_id"], name: "index_goals_on_goalable"
    t.index ["workspace_id"], name: "index_goals_on_workspace_id"
  end

  create_table "integration_accounts", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "provider", null: false
    t.string "name", null: false
    t.text "token_ciphertext"
    t.json "metadata", default: {}, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_integration_accounts_on_workspace_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id"
    t.string "email", null: false
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.datetime "accepted_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_invitations_on_team_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["workspace_id"], name: "index_invitations_on_workspace_id"
  end

  create_table "issue_labels", force: :cascade do |t|
    t.integer "issue_id", null: false
    t.integer "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_id", "label_id"], name: "index_issue_labels_on_issue_id_and_label_id", unique: true
    t.index ["issue_id"], name: "index_issue_labels_on_issue_id"
    t.index ["label_id"], name: "index_issue_labels_on_label_id"
  end

  create_table "issue_relations", force: :cascade do |t|
    t.integer "source_issue_id", null: false
    t.integer "target_issue_id", null: false
    t.string "relation_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_issue_id"], name: "index_issue_relations_on_source_issue_id"
    t.index ["target_issue_id"], name: "index_issue_relations_on_target_issue_id"
  end

  create_table "issue_statuses", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id", null: false
    t.string "name", null: false
    t.string "category", default: "backlog", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_issue_statuses_on_team_id"
    t.index ["workspace_id"], name: "index_issue_statuses_on_workspace_id"
  end

  create_table "issues", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id", null: false
    t.integer "project_id"
    t.integer "cycle_id"
    t.integer "issue_status_id"
    t.integer "assignee_id"
    t.integer "parent_id"
    t.string "identifier", null: false
    t.string "title", null: false
    t.text "description"
    t.string "priority", default: "medium", null: false
    t.integer "estimate"
    t.date "due_on"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_issues_on_assignee_id"
    t.index ["cycle_id"], name: "index_issues_on_cycle_id"
    t.index ["issue_status_id"], name: "index_issues_on_issue_status_id"
    t.index ["parent_id"], name: "index_issues_on_parent_id"
    t.index ["project_id"], name: "index_issues_on_project_id"
    t.index ["team_id"], name: "index_issues_on_team_id"
    t.index ["workspace_id", "identifier"], name: "index_issues_on_workspace_id_and_identifier", unique: true
    t.index ["workspace_id"], name: "index_issues_on_workspace_id"
  end

  create_table "labels", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "name", null: false
    t.string "color", default: "#71717a", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id"], name: "index_labels_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id"
    t.integer "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id", "team_id", "user_id"], name: "index_memberships_on_workspace_id_and_team_id_and_user_id", unique: true
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "objectives", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "objectiveable_type"
    t.integer "objectiveable_id"
    t.string "title", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["objectiveable_type", "objectiveable_id"], name: "index_objectives_on_objectiveable"
    t.index ["workspace_id"], name: "index_objectives_on_workspace_id"
  end

  create_table "pipeline_definitions", force: :cascade do |t|
    t.integer "workspace_id"
    t.string "key", null: false
    t.string "name", null: false
    t.json "required_context", default: {}, null: false
    t.json "graph", default: {"nodes" => [], "edges" => []}, null: false
    t.json "triggers", default: [], null: false
    t.json "permissions", default: [], null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0.0", null: false
    t.index ["workspace_id", "key", "version"], name: "index_pipeline_definitions_on_workspace_key_version", unique: true
    t.index ["workspace_id"], name: "index_pipeline_definitions_on_workspace_id"
  end

  create_table "pipeline_runs", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "pipeline_definition_id"
    t.integer "user_id"
    t.integer "project_id"
    t.integer "issue_id"
    t.integer "event_id"
    t.string "status", default: "queued", null: false
    t.string "trigger", default: "manual", null: false
    t.json "input_context", default: {}, null: false
    t.json "pipeline_snapshot", default: {}, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "automation_seconds_used", default: 0, null: false
    t.datetime "usage_recorded_at"
    t.index ["event_id"], name: "index_pipeline_runs_on_event_id"
    t.index ["issue_id"], name: "index_pipeline_runs_on_issue_id"
    t.index ["pipeline_definition_id"], name: "index_pipeline_runs_on_pipeline_definition_id"
    t.index ["project_id"], name: "index_pipeline_runs_on_project_id"
    t.index ["user_id"], name: "index_pipeline_runs_on_user_id"
    t.index ["workspace_id"], name: "index_pipeline_runs_on_workspace_id"
  end

  create_table "plan_records", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "plannable_type"
    t.integer "plannable_id"
    t.string "title", null: false
    t.text "body"
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plannable_type", "plannable_id"], name: "index_plan_records_on_plannable"
    t.index ["workspace_id"], name: "index_plan_records_on_workspace_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id", null: false
    t.string "title", null: false
    t.string "key", null: false
    t.text "description"
    t.string "status", default: "planned", null: false
    t.string "repository_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_projects_on_team_id"
    t.index ["workspace_id", "key"], name: "index_projects_on_workspace_id_and_key", unique: true
    t.index ["workspace_id"], name: "index_projects_on_workspace_id"
  end

  create_table "repository_connections", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "integration_account_id"
    t.string "provider", null: false
    t.string "name", null: false
    t.string "full_name"
    t.string "url", null: false
    t.string "default_branch", default: "main", null: false
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_account_id"], name: "index_repository_connections_on_integration_account_id"
    t.index ["workspace_id"], name: "index_repository_connections_on_workspace_id"
  end

  create_table "run_artifacts", force: :cascade do |t|
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.string "name", null: false
    t.string "path", null: false
    t.string "content_type"
    t.integer "byte_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_run_step_id"], name: "index_run_artifacts_on_action_run_step_id"
    t.index ["pipeline_run_id"], name: "index_run_artifacts_on_pipeline_run_id"
  end

  create_table "run_logs", force: :cascade do |t|
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.string "level", default: "info", null: false
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_run_step_id"], name: "index_run_logs_on_action_run_step_id"
    t.index ["pipeline_run_id"], name: "index_run_logs_on_pipeline_run_id"
  end

  create_table "run_messages", force: :cascade do |t|
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.integer "user_id"
    t.string "role", null: false
    t.string "kind", default: "text", null: false
    t.string "status", default: "resolved", null: false
    t.text "content"
    t.json "payload", default: {}, null: false
    t.datetime "answered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_run_step_id"], name: "index_run_messages_on_action_run_step_id"
    t.index ["pipeline_run_id", "created_at"], name: "index_run_messages_on_pipeline_run_id_and_created_at"
    t.index ["pipeline_run_id", "status"], name: "index_run_messages_on_pipeline_run_id_and_status"
    t.index ["pipeline_run_id"], name: "index_run_messages_on_pipeline_run_id"
    t.index ["user_id"], name: "index_run_messages_on_user_id"
  end

  create_table "sandbox_commands", force: :cascade do |t|
    t.integer "sandbox_session_id", null: false
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.integer "user_id"
    t.string "status", default: "queued", null: false
    t.text "command", null: false
    t.text "stdout"
    t.text "stderr"
    t.integer "exit_status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_run_step_id"], name: "index_sandbox_commands_on_action_run_step_id"
    t.index ["pipeline_run_id", "status"], name: "index_sandbox_commands_on_pipeline_run_id_and_status"
    t.index ["pipeline_run_id"], name: "index_sandbox_commands_on_pipeline_run_id"
    t.index ["sandbox_session_id", "created_at"], name: "index_sandbox_commands_on_sandbox_session_id_and_created_at"
    t.index ["sandbox_session_id"], name: "index_sandbox_commands_on_sandbox_session_id"
    t.index ["user_id"], name: "index_sandbox_commands_on_user_id"
  end

  create_table "sandbox_sessions", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "project_id"
    t.integer "pipeline_run_id", null: false
    t.integer "action_run_step_id"
    t.string "kind", default: "docker_worktree", null: false
    t.string "status", default: "provisioning", null: false
    t.string "worktree_path"
    t.string "container_id"
    t.string "browser_session_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "expires_at"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "execution_environment_id"
    t.index ["action_run_step_id", "kind"], name: "index_sandbox_sessions_on_action_run_step_id_and_kind"
    t.index ["action_run_step_id"], name: "index_sandbox_sessions_on_action_run_step_id"
    t.index ["execution_environment_id"], name: "index_sandbox_sessions_on_execution_environment_id"
    t.index ["pipeline_run_id", "status"], name: "index_sandbox_sessions_on_pipeline_run_id_and_status"
    t.index ["pipeline_run_id"], name: "index_sandbox_sessions_on_pipeline_run_id"
    t.index ["project_id"], name: "index_sandbox_sessions_on_project_id"
    t.index ["workspace_id"], name: "index_sandbox_sessions_on_workspace_id"
  end

  create_table "saved_views", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "team_id"
    t.string "name", null: false
    t.string "key", null: false
    t.string "view_type", null: false
    t.json "filters", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_saved_views_on_team_id"
    t.index ["workspace_id"], name: "index_saved_views_on_workspace_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.integer "pipeline_definition_id", null: false
    t.string "schedulable_type"
    t.integer "schedulable_id"
    t.string "kind", null: false
    t.datetime "run_at"
    t.string "cron"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_definition_id"], name: "index_schedules_on_pipeline_definition_id"
    t.index ["schedulable_type", "schedulable_id"], name: "index_schedules_on_schedulable"
    t.index ["workspace_id"], name: "index_schedules_on_workspace_id"
  end

  create_table "skill_definitions", force: :cascade do |t|
    t.integer "workspace_id"
    t.string "key", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.text "description"
    t.text "instructions"
    t.text "objective_template"
    t.text "plan_template"
    t.json "input_schema", default: {}, null: false
    t.json "output_schema", default: {}, null: false
    t.json "best_practices", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.boolean "builtin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0.0", null: false
    t.index ["workspace_id", "key", "version"], name: "index_skill_definitions_on_workspace_key_version", unique: true
    t.index ["workspace_id"], name: "index_skill_definitions_on_workspace_id"
  end

  create_table "sso_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "sso_provider_id", null: false
    t.string "provider_uid", null: false
    t.string "email", default: "", null: false
    t.string "name", default: "", null: false
    t.json "raw_info", default: {}, null: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sso_provider_id", "email"], name: "index_sso_identities_on_sso_provider_id_and_email"
    t.index ["sso_provider_id", "provider_uid"], name: "index_sso_identities_on_sso_provider_id_and_provider_uid", unique: true
    t.index ["sso_provider_id"], name: "index_sso_identities_on_sso_provider_id"
    t.index ["user_id"], name: "index_sso_identities_on_user_id"
  end

  create_table "sso_providers", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "name", null: false
    t.string "provider_type", default: "oidc", null: false
    t.string "status", default: "active", null: false
    t.string "issuer"
    t.string "authorization_endpoint"
    t.string "token_endpoint"
    t.string "userinfo_endpoint"
    t.string "client_id"
    t.string "client_secret_ciphertext"
    t.string "scopes", default: "openid email profile", null: false
    t.string "email_domain"
    t.boolean "allow_signups", default: true, null: false
    t.string "default_membership_role", default: "member", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "name"], name: "index_sso_providers_on_workspace_id_and_name", unique: true
    t.index ["workspace_id"], name: "index_sso_providers_on_workspace_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.string "name", null: false
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workspace_id", "key"], name: "index_teams_on_workspace_id_and_key", unique: true
    t.index ["workspace_id"], name: "index_teams_on_workspace_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.string "theme_preference", default: "system", null: false
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.boolean "demo", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "billing_plan", default: "community", null: false
    t.string "stripe_customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "demo", default: false, null: false
    t.string "webhook_secret", null: false
    t.index ["slug"], name: "index_workspaces_on_slug", unique: true
    t.index ["webhook_secret"], name: "index_workspaces_on_webhook_secret", unique: true
  end

  add_foreign_key "action_definitions", "agent_definitions"
  add_foreign_key "action_definitions", "skill_definitions"
  add_foreign_key "action_definitions", "workspaces"
  add_foreign_key "action_run_steps", "action_definitions"
  add_foreign_key "action_run_steps", "pipeline_runs"
  add_foreign_key "admin_model_requests", "code_model_profiles"
  add_foreign_key "agent_definitions", "agent_definitions", column: "parent_agent_definition_id"
  add_foreign_key "agent_definitions", "workspaces"
  add_foreign_key "agent_swarm_definitions", "agent_definitions", column: "coordinator_agent_definition_id"
  add_foreign_key "agent_swarm_definitions", "workspaces"
  add_foreign_key "agent_swarm_memberships", "agent_definitions"
  add_foreign_key "agent_swarm_memberships", "agent_swarm_definitions"
  add_foreign_key "approvals", "action_run_steps"
  add_foreign_key "approvals", "pipeline_runs"
  add_foreign_key "approvals", "users"
  add_foreign_key "audit_events", "users"
  add_foreign_key "audit_events", "workspaces"
  add_foreign_key "automation_runs", "workspaces"
  add_foreign_key "billing_subscriptions", "workspaces"
  add_foreign_key "change_requests", "issues"
  add_foreign_key "change_requests", "pipeline_runs"
  add_foreign_key "change_requests", "repository_connections"
  add_foreign_key "change_requests", "workspaces"
  add_foreign_key "code_model_profiles", "workspaces"
  add_foreign_key "codex_session_messages", "codex_sessions"
  add_foreign_key "codex_session_messages", "users"
  add_foreign_key "codex_sessions", "pipeline_runs"
  add_foreign_key "codex_sessions", "projects"
  add_foreign_key "codex_sessions", "sandbox_sessions"
  add_foreign_key "codex_sessions", "users"
  add_foreign_key "codex_sessions", "workspaces"
  add_foreign_key "cycles", "teams"
  add_foreign_key "cycles", "workspaces"
  add_foreign_key "event_rules", "workspaces"
  add_foreign_key "events", "issues"
  add_foreign_key "events", "projects"
  add_foreign_key "events", "workspaces"
  add_foreign_key "execution_environments", "projects"
  add_foreign_key "execution_environments", "workspaces"
  add_foreign_key "goals", "workspaces"
  add_foreign_key "integration_accounts", "workspaces"
  add_foreign_key "invitations", "teams"
  add_foreign_key "invitations", "workspaces"
  add_foreign_key "issue_labels", "issues"
  add_foreign_key "issue_labels", "labels"
  add_foreign_key "issue_relations", "issues", column: "source_issue_id"
  add_foreign_key "issue_relations", "issues", column: "target_issue_id"
  add_foreign_key "issue_statuses", "teams"
  add_foreign_key "issue_statuses", "workspaces"
  add_foreign_key "issues", "cycles"
  add_foreign_key "issues", "issue_statuses"
  add_foreign_key "issues", "issues", column: "parent_id"
  add_foreign_key "issues", "projects"
  add_foreign_key "issues", "teams"
  add_foreign_key "issues", "users", column: "assignee_id"
  add_foreign_key "issues", "workspaces"
  add_foreign_key "labels", "workspaces"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "objectives", "workspaces"
  add_foreign_key "pipeline_definitions", "workspaces"
  add_foreign_key "pipeline_runs", "events"
  add_foreign_key "pipeline_runs", "issues"
  add_foreign_key "pipeline_runs", "pipeline_definitions"
  add_foreign_key "pipeline_runs", "projects"
  add_foreign_key "pipeline_runs", "users"
  add_foreign_key "pipeline_runs", "workspaces"
  add_foreign_key "plan_records", "workspaces"
  add_foreign_key "projects", "teams"
  add_foreign_key "projects", "workspaces"
  add_foreign_key "repository_connections", "integration_accounts"
  add_foreign_key "repository_connections", "workspaces"
  add_foreign_key "run_artifacts", "action_run_steps"
  add_foreign_key "run_artifacts", "pipeline_runs"
  add_foreign_key "run_logs", "action_run_steps"
  add_foreign_key "run_logs", "pipeline_runs"
  add_foreign_key "run_messages", "action_run_steps"
  add_foreign_key "run_messages", "pipeline_runs"
  add_foreign_key "run_messages", "users"
  add_foreign_key "sandbox_commands", "action_run_steps"
  add_foreign_key "sandbox_commands", "pipeline_runs"
  add_foreign_key "sandbox_commands", "sandbox_sessions"
  add_foreign_key "sandbox_commands", "users"
  add_foreign_key "sandbox_sessions", "action_run_steps"
  add_foreign_key "sandbox_sessions", "execution_environments"
  add_foreign_key "sandbox_sessions", "pipeline_runs"
  add_foreign_key "sandbox_sessions", "projects"
  add_foreign_key "sandbox_sessions", "workspaces"
  add_foreign_key "saved_views", "teams"
  add_foreign_key "saved_views", "workspaces"
  add_foreign_key "schedules", "pipeline_definitions"
  add_foreign_key "schedules", "workspaces"
  add_foreign_key "skill_definitions", "workspaces"
  add_foreign_key "sso_identities", "sso_providers"
  add_foreign_key "sso_identities", "users"
  add_foreign_key "sso_providers", "workspaces"
  add_foreign_key "teams", "workspaces"
end

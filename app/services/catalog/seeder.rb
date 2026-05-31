module Catalog
  class Seeder
    ACTIONS = [
      [ "plan-story", "Plan Story", "planning", "codex", [ "view_project" ] ],
      [ "verify-plan", "Verify Plan", "verification", "manual", [ "approve_change_requests" ] ],
      [ "revise-plan", "Revise Plan", "planning", "manual", [ "edit_issues" ] ],
      [ "code", "Code", "coding", "codex", [ "run_code_actions" ] ],
      [ "review-diff", "Review Diff", "review", "manual", [ "approve_change_requests" ] ],
      [ "run-tests", "Run Tests", "verification", "local_shell", [ "run_code_actions" ] ],
      [ "security-scan", "Run Security Scan", "verification", "local_shell", [ "run_code_actions" ] ],
      [ "open-change-request", "Open Change Request", "review", "local_shell", [ "approve_change_requests" ] ],
      [ "manual-approval", "Manual Approval", "manual", "manual", [ "approve_change_requests" ] ],
      [ "update-dependencies", "Update Dependencies", "maintenance", "local_shell", [ "run_code_actions" ] ],
      [ "handle-event", "Handle Event", "incident", "manual", [ "edit_issues" ] ],
      [ "release", "Release", "release", "manual", [ "approve_change_requests" ] ]
    ].freeze

    PIPELINES = [
      [ "implement-issue", "Implement Issue", %w[plan-story verify-plan code run-tests review-diff open-change-request] ],
      [ "update-dependencies", "Update Dependencies", %w[update-dependencies run-tests open-change-request] ],
      [ "fix-failing-build", "Fix Failing Build", %w[handle-event plan-story code run-tests open-change-request] ],
      [ "handle-production-event", "Handle Production Event", %w[handle-event plan-story manual-approval code run-tests open-change-request] ],
      [ "review-change-request", "Review Change Request", %w[review-diff security-scan manual-approval] ],
      [ "release-project", "Release Project", %w[run-tests security-scan manual-approval release] ]
    ].freeze

    DEFAULT_INPUT_SCHEMA = {
      type: "object",
      properties: {
        objective: { type: "string" },
        issue_id: { type: "integer" },
        project_id: { type: "integer" },
        command: { type: "string" }
      },
      additionalProperties: true
    }.freeze

    DEFAULT_OUTPUT_SCHEMA = {
      type: "object",
      properties: {
        summary: { type: "string" },
        status: { type: "string" },
        changed_files_count: { type: "integer" }
      },
      additionalProperties: true
    }.freeze

    def self.seed!(workspace)
      new(workspace).seed!
    end

    def initialize(workspace)
      @workspace = workspace
    end

    def seed!
      action_index = seed_actions
      seed_pipelines(action_index)
    end

    private

    def seed_actions
      ACTIONS.each_with_object({}) do |(key, name, category, provider, permissions), index|
        index[key] = @workspace.action_definitions.find_or_create_by!(key: key) do |action|
          action.name = name
          action.category = category
          action.provider = provider
          action.permissions = permissions
          action.input_schema = DEFAULT_INPUT_SCHEMA
          action.output_schema = DEFAULT_OUTPUT_SCHEMA
          action.defaults = default_for(key)
          action.runtime_config = runtime_for(key)
          action.builtin = true
        end
      end
    end

    def seed_pipelines(action_index)
      PIPELINES.each do |key, name, action_keys|
        @workspace.pipeline_definitions.find_or_create_by!(key: key) do |pipeline|
          pipeline.name = name
          pipeline.required_context = { "repository" => action_keys.include?("code"), "issue" => key.include?("issue") }
          pipeline.graph = graph_for(action_index.values_at(*action_keys).compact)
          pipeline.triggers = [ "manual" ]
          pipeline.permissions = action_keys.flat_map { |action_key| action_index[action_key]&.permissions }.compact.uniq
          pipeline.builtin = true
        end
      end
    end

    def graph_for(actions)
      nodes = actions.each_with_index.map do |action, index|
        { id: "node-#{index + 1}", action_key: action.key, action_id: action.id, label: action.name, x: 120 + (index * 220), y: 160 }
      end
      edges = nodes.each_cons(2).map do |from, to|
        { id: "#{from[:id]}-#{to[:id]}", from: from[:id], to: to[:id], condition: "success" }
      end
      { nodes: nodes, edges: edges }
    end

    def default_for(key)
      case key
      when "run-tests"
        { command: "bin/rails test" }
      when "security-scan"
        { command: "bin/brakeman --no-pager" }
      when "update-dependencies"
        { command: "bundle update --patch" }
      else
        {}
      end
    end

    def runtime_for(key)
      key.in?(%w[run-tests security-scan update-dependencies open-change-request]) ? { shell: true } : {}
    end
  end
end

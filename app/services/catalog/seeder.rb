module Catalog
  class Seeder
    SKILLS = [
      [ "story-planning", "Story Planning", "planning", "Turn loose requests into explicit objectives, constraints, and reviewable plans." ],
      [ "software-implementation", "Software Implementation", "coding", "Change code in scoped branches with clear objectives, tests, and Change Requests." ],
      [ "verification", "Verification", "verification", "Run checks, interpret failures, and produce evidence for reviewers." ],
      [ "change-review", "Change Review", "review", "Review diffs and package code-changing work into auditable Change Requests." ],
      [ "incident-response", "Incident Response", "incident", "Convert operational events into prioritized issues and automation runs." ],
      [ "release-operations", "Release Operations", "release", "Prepare releases with approvals, rollback thinking, and validation evidence." ],
      [ "maintenance", "Maintenance", "maintenance", "Keep projects healthy through recurring dependency and hygiene workflows." ],
      [ "manual-decision", "Manual Decision", "manual", "Pause automation for a clear human decision with enough context to approve, revise, or reject." ]
    ].freeze

    ACTIONS = [
      [ "plan-story", "Plan Story", "planning", "codex", [ "view_project" ], "story-planning" ],
      [ "verify-plan", "Verify Plan", "verification", "manual", [ "approve_change_requests" ], "manual-decision" ],
      [ "revise-plan", "Revise Plan", "planning", "manual", [ "edit_issues" ], "story-planning" ],
      [ "code", "Code", "coding", "codex", [ "run_code_actions" ], "software-implementation" ],
      [ "review-diff", "Review Diff", "review", "manual", [ "approve_change_requests" ], "change-review" ],
      [ "run-tests", "Run Tests", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "security-scan", "Run Security Scan", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "open-change-request", "Open Change Request", "review", "local_shell", [ "approve_change_requests" ], "change-review" ],
      [ "manual-approval", "Manual Approval", "manual", "manual", [ "approve_change_requests" ], "manual-decision" ],
      [ "update-dependencies", "Update Dependencies", "maintenance", "local_shell", [ "run_code_actions" ], "maintenance" ],
      [ "handle-event", "Handle Event", "incident", "manual", [ "edit_issues" ], "incident-response" ],
      [ "release", "Release", "release", "manual", [ "approve_change_requests" ], "release-operations" ]
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
      skill_index = seed_skills
      action_index = seed_actions(skill_index)
      seed_pipelines(action_index)
    end

    private

    def seed_skills
      SKILLS.each_with_object({}) do |(key, name, category, description), index|
        skill = @workspace.skill_definitions.find_or_initialize_by(key: key)
        skill.assign_attributes(
          name: name,
          category: category,
          description: description,
          instructions: instructions_for(key),
          objective_template: "Use {{skill}} to accomplish a clear outcome for {{issue}} {{issue_title}} in {{project}}.",
          plan_template: "Clarify objective, inspect current state, choose the safest next step, execute with evidence, and summarize output.",
          input_schema: DEFAULT_INPUT_SCHEMA,
          output_schema: DEFAULT_OUTPUT_SCHEMA,
          best_practices: skill_best_practices_for(key),
          builtin: true
        )
        skill.save!
        index[key] = skill
      end
    end

    def seed_actions(skill_index)
      ACTIONS.each_with_object({}) do |(key, name, category, provider, permissions, skill_key), index|
        action = @workspace.action_definitions.find_or_initialize_by(key: key)
        action.assign_attributes(
          name: name,
          category: category,
          provider: provider,
          permissions: permissions,
          skill_definition: skill_index[skill_key],
          input_schema: DEFAULT_INPUT_SCHEMA,
          output_schema: DEFAULT_OUTPUT_SCHEMA,
          defaults: default_for(key),
          runtime_config: runtime_for(key),
          objective_template: objective_for(key),
          plan_template: plan_for(key),
          execution_guidance: guidance_for(key),
          best_practices: action_best_practices_for(key),
          builtin: true
        )
        action.save!
        index[key] = action
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

    def instructions_for(key)
      case key
      when "story-planning"
        "Produce plans that name the objective, constraints, risks, dependencies, and acceptance checks before coding starts."
      when "software-implementation"
        "Make scoped code changes in a branch-oriented flow, preserve user work, run focused checks, and prepare a Change Request."
      when "verification"
        "Prefer repeatable commands and structured evidence. Treat failures as inputs for the next action, not as terminal noise."
      when "change-review"
        "Connect the diff back to the objective and call out risk, tests, artifacts, and unresolved questions."
      when "incident-response"
        "Normalize incoming events, classify severity, create actionable work, and connect it to a pipeline or owner."
      when "maintenance"
        "Keep changes small, reversible, and backed by tests, especially for dependencies and scheduled hygiene."
      when "manual-decision"
        "Ask for a concrete approve, revise, trigger, or reject decision with the plan and evidence visible."
      else
        "Follow the action objective, preserve context, validate the result, and record output."
      end
    end

    def skill_best_practices_for(key)
      case key
      when "software-implementation"
        [ "Start from an explicit objective.", "Prefer the repository's existing patterns.", "Every code-changing run must produce a Change Request." ]
      when "manual-decision"
        [ "State what is being decided.", "Show the current plan and evidence.", "Offer approve, revise, trigger, or reject outcomes." ]
      else
        [ "Make the objective explicit.", "Record assumptions and constraints.", "Return structured outputs that downstream actions can use." ]
      end
    end

    def objective_for(key)
      case key
      when "plan-story"
        "Create a concrete implementation plan for {{issue}} {{issue_title}} in {{project}}."
      when "code"
        "Implement the approved plan for {{issue}} {{issue_title}} in {{project}}."
      when "run-tests"
        "Verify the current change for {{issue}} {{issue_title}} in {{project}}."
      when "open-change-request"
        "Package the completed work for {{issue}} {{issue_title}} into a new Change Request."
      when "update-dependencies"
        "Update project dependencies safely for {{project}} and prepare review evidence."
      else
        "Complete {{action}} for {{issue}} {{issue_title}} in {{project}}."
      end
    end

    def plan_for(key)
      case key
      when "plan-story"
        "Read the issue, infer missing context, identify risks, define acceptance checks, and output a reviewable plan."
      when "code"
        "Confirm the approved plan, edit only relevant files, run focused checks, capture artifacts, and prepare for review."
      when "run-tests"
        "Choose the narrowest meaningful test command first, run it, capture output, and report failures as structured evidence."
      when "open-change-request"
        "Confirm branch naming, summarize objective and tests, create or record the Change Request, and link it to the run."
      else
        "Clarify the objective, inspect inputs, perform the action, validate output, and record evidence."
      end
    end

    def guidance_for(key)
      case key
      when "verify-plan", "manual-approval"
        "Pause until a human confirms whether the objective and plan are clear enough to continue."
      when "revise-plan"
        "Update the plan while preserving the original objective and unresolved constraints."
      else
        "Use the objective and plan fields as the action contract. If objective is unclear, produce or request a better plan before doing irreversible work."
      end
    end

    def action_best_practices_for(key)
      base = [ "Use structured input and output.", "Keep the action scoped to its objective.", "Record evidence for the next pipeline step." ]
      return base + [ "Do not change the main checkout directly.", "Every code change should end in a new Change Request." ] if key.in?(%w[code update-dependencies open-change-request])
      return base + [ "Make approval choices explicit: approve, revise, trigger, or reject." ] if key.in?(%w[verify-plan manual-approval review-diff])

      base
    end
  end
end

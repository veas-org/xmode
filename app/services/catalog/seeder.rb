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
      [ "manual-decision", "Manual Decision", "manual", "Pause automation for a clear human decision with enough context to approve, revise, or reject." ],
      [ "cloud-sandbox-implementation", "Cloud Sandbox Implementation", "coding", "Run agent coding work inside hosted sandbox workers with logs, diffs, artifacts, and Change Requests." ]
    ].freeze

    ACTIONS = [
      [ "plan-story", "Plan Story", "planning", "codex", [ "view_project" ], "story-planning" ],
      [ "local-model-plan", "Local Model Plan", "planning", "local_model", [ "view_project" ], "story-planning" ],
      [ "verify-plan", "Verify Plan", "verification", "manual", [ "approve_change_requests" ], "manual-decision" ],
      [ "revise-plan", "Revise Plan", "planning", "manual", [ "edit_issues" ], "story-planning" ],
      [ "code", "Code", "coding", "codex", [ "run_code_actions" ], "software-implementation" ],
      [ "review-diff", "Review Diff", "review", "manual", [ "approve_change_requests" ], "change-review" ],
      [ "run-tests", "Run Tests", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "security-scan", "Run Security Scan", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "verify-typescript-sandbox", "Verify TypeScript Sandbox", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "verify-ruby-rails-sandbox", "Verify Ruby Rails Sandbox", "verification", "local_shell", [ "run_code_actions" ], "verification" ],
      [ "cloud-rails-code", "Cloud Rails Code", "coding", "local_shell", [ "run_code_actions" ], "cloud-sandbox-implementation" ],
      [ "codex-plan-dependencies", "Codex Plan Dependencies", "planning", "local_shell", [ "run_code_actions" ], "cloud-sandbox-implementation" ],
      [ "codex-update-dependencies", "Codex Update Dependencies", "maintenance", "local_shell", [ "run_code_actions" ], "cloud-sandbox-implementation" ],
      [ "present-sandbox-result", "Present Sandbox Result", "review", "local_model", [ "view_project" ], "change-review" ],
      [ "open-change-request", "Open Change Request", "review", "local_shell", [ "approve_change_requests" ], "change-review" ],
      [ "manual-approval", "Manual Approval", "manual", "manual", [ "approve_change_requests" ], "manual-decision" ],
      [ "update-dependencies", "Update Dependencies", "maintenance", "local_shell", [ "run_code_actions" ], "maintenance" ],
      [ "handle-event", "Handle Event", "incident", "manual", [ "edit_issues" ], "incident-response" ],
      [ "release", "Release", "release", "manual", [ "approve_change_requests" ], "release-operations" ]
    ].freeze

    PIPELINES = [
      [ "implement-issue", "Implement Issue", %w[plan-story verify-plan code run-tests review-diff open-change-request] ],
      [ "update-dependencies", "Update Dependencies", %w[update-dependencies run-tests open-change-request] ],
      [ "codex-update-dependencies", "Codex Update Dependencies", %w[codex-plan-dependencies manual-approval codex-update-dependencies run-tests open-change-request] ],
      [ "fix-failing-build", "Fix Failing Build", %w[handle-event plan-story code run-tests open-change-request] ],
      [ "handle-production-event", "Handle Production Event", %w[handle-event plan-story manual-approval code run-tests open-change-request] ],
      [ "review-change-request", "Review Change Request", %w[review-diff security-scan manual-approval] ],
      [ "release-project", "Release Project", %w[run-tests security-scan manual-approval release] ],
      [ "verify-sandbox-fixture", "Verify Sandbox Fixture", %w[verify-typescript-sandbox open-change-request] ],
      [ "verify-rails-sandbox-fixture", "Verify Rails Sandbox Fixture", %w[verify-ruby-rails-sandbox open-change-request] ],
      [ "local-model-planning-demo", "Local Model Planning Demo", %w[local-model-plan verify-plan] ]
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

    PLAN_OUTPUT_SCHEMA = {
      type: "object",
      required: %w[summary status plan next_steps acceptance_checks],
      properties: {
        summary: { type: "string", description: "One sentence describing the proposed implementation plan." },
        status: { type: "string", enum: %w[planned needs_input failed] },
        plan: { type: "string", description: "Concise numbered Markdown plan. It must include the sandbox boundary." },
        next_steps: {
          type: "array",
          items: { type: "string" },
          description: "Concrete next actions after plan approval."
        },
        acceptance_checks: {
          type: "array",
          items: { type: "string" },
          description: "Evidence needed to accept the run."
        },
        risks: {
          type: "array",
          items: { type: "string" }
        },
        changed_files_count: { type: "integer" }
      },
      additionalProperties: true
    }.freeze

    PRESENT_RESULT_OUTPUT_SCHEMA = {
      type: "object",
      required: %w[summary status changed_files tests artifacts review_action changed_files_count],
      properties: {
        summary: { type: "string", description: "Concise reviewer-facing result summary." },
        status: { type: "string", enum: %w[completed needs_input failed] },
        changed_files: {
          type: "array",
          items: { type: "string" },
          description: "Repository paths changed by the sandbox run."
        },
        tests: {
          type: "array",
          items: { type: "string" },
          description: "Commands or evidence proving validation."
        },
        artifacts: {
          type: "array",
          items: { type: "string" },
          description: "Artifacts a reviewer should inspect."
        },
        review_action: { type: "string", description: "Recommended next review action." },
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
      seed_interactive_pipelines(action_index)
      seed_cloud_sandbox_pipelines(action_index)
    end

    private

    def seed_skills
      SKILLS.each_with_object({}) do |(key, name, category, description), index|
        skill = @workspace.skill_definitions.find_or_initialize_by(key: key, version: "1.0.0")
        skill.assign_attributes(
          name: name,
          version: "1.0.0",
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
        action = @workspace.action_definitions.find_or_initialize_by(key: key, version: "1.0.0")
        action.assign_attributes(
          name: name,
          category: category,
          provider: provider,
          permissions: permissions,
          skill_definition: skill_index[skill_key],
          input_schema: DEFAULT_INPUT_SCHEMA,
          output_schema: output_schema_for(key),
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
        pipeline = @workspace.pipeline_definitions.find_or_initialize_by(key: key, version: "1.0.0")
        pipeline.assign_attributes(
          name: name,
          required_context: { "repository" => action_keys.intersect?(%w[code verify-typescript-sandbox verify-ruby-rails-sandbox]), "issue" => key.include?("issue") },
          graph: graph_for(action_index.values_at(*action_keys).compact),
          triggers: [ "manual" ],
          permissions: action_keys.flat_map { |action_key| action_index[action_key]&.permissions }.compact.uniq,
          builtin: true
        )
        pipeline.save!
      end
    end

    def graph_for(actions)
      nodes = actions.each_with_index.map do |action, index|
        { id: "node-#{index + 1}", action_key: action.key, action_version: action.version, action_id: action.id, label: action.name, x: 120 + (index * 220), y: 160 }
      end
      edges = nodes.each_cons(2).map do |from, to|
        { id: "#{from[:id]}-#{to[:id]}", from: from[:id], to: to[:id], condition: "success" }
      end
      { nodes: nodes, edges: edges }
    end

    def seed_interactive_pipelines(action_index)
      pipeline = @workspace.pipeline_definitions.find_or_initialize_by(key: "guided-implement-issue", version: "1.0.0")
      pipeline.assign_attributes(
        name: "Guided Implement Issue",
        required_context: { "repository" => true, "issue" => true },
        graph: guided_implementation_graph(action_index),
        triggers: [ "manual" ],
        permissions: %w[view_project edit_issues run_code_actions approve_change_requests],
        builtin: true
      )
      pipeline.save!
    end

    def seed_cloud_sandbox_pipelines(action_index)
      pipeline = @workspace.pipeline_definitions.find_or_initialize_by(key: "cloud-rails-implement-issue", version: "1.0.0")
      pipeline.assign_attributes(
        name: "Cloud Rails Implement Issue",
        required_context: { "repository" => true, "issue" => true, "cloud_sandbox" => true },
        graph: cloud_rails_implementation_graph(action_index),
        triggers: [ "manual" ],
        permissions: %w[view_project edit_issues run_code_actions approve_change_requests],
        builtin: true
      )
      pipeline.save!
    end

    def guided_implementation_graph(action_index)
      action_node = ->(id, action_key, x) do
        action = action_index.fetch(action_key)
        { id: id, type: "action", action_key: action.key, action_version: action.version, action_id: action.id, label: action.name, x: x, y: 160 }
      end

      nodes = [
        {
          id: "clarify-objective",
          type: "decision",
          label: "Clarify Objective",
          question: "The issue may be missing acceptance criteria. How should the pipeline proceed?",
          choices: [
            { key: "infer", label: "Infer from issue context", next: "goal-check" },
            { key: "ask", label: "Ask for follow-up", next: "follow-up" },
            { key: "stop", label: "Stop and report", action: "reject" }
          ],
          x: 120,
          y: 160
        },
        {
          id: "follow-up",
          type: "follow_up",
          label: "Follow-up",
          prompt: "Add the missing constraints or acceptance criteria before planning.",
          x: 340,
          y: 260
        },
        {
          id: "goal-check",
          type: "goal_check",
          label: "Goal Check",
          question: "Confirm the run goal before coding starts.",
          checks: [
            "Objective is explicit",
            "Plan can be reviewed before code",
            "Tests and Change Request evidence will be captured"
          ],
          choices: [
            { key: "approve", label: "Goal is clear", next: "plan-story" },
            { key: "revise", label: "Revise objective", next: "follow-up" }
          ],
          x: 560,
          y: 160
        },
        action_node.call("plan-story", "plan-story", 780),
        action_node.call("code", "code", 1_000),
        action_node.call("run-tests", "run-tests", 1_220),
        action_node.call("open-change-request", "open-change-request", 1_440)
      ]

      edges = [
        { id: "clarify-objective-goal-check", from: "clarify-objective", to: "goal-check", condition: "choice:infer" },
        { id: "clarify-objective-follow-up", from: "clarify-objective", to: "follow-up", condition: "choice:ask" },
        { id: "follow-up-goal-check", from: "follow-up", to: "goal-check", condition: "answered" },
        { id: "goal-check-plan-story", from: "goal-check", to: "plan-story", condition: "choice:approve" },
        { id: "goal-check-follow-up", from: "goal-check", to: "follow-up", condition: "choice:revise" },
        { id: "plan-story-code", from: "plan-story", to: "code", condition: "success" },
        { id: "code-run-tests", from: "code", to: "run-tests", condition: "success" },
        { id: "run-tests-open-change-request", from: "run-tests", to: "open-change-request", condition: "success" }
      ]

      { nodes: nodes, edges: edges }
    end

    def cloud_rails_implementation_graph(action_index)
      action_node = ->(id, action_key, x) do
        action = action_index.fetch(action_key)
        { id: id, type: "action", action_key: action.key, action_version: action.version, action_id: action.id, label: action.name, x: x, y: 160 }
      end

      nodes = [
        action_node.call("draft-plan", "local-model-plan", 120),
        {
          id: "review-plan",
          type: "decision",
          label: "Review Plan",
          question: "Review Qwen's implementation plan before cloud sandbox coding starts.",
          choices: [
            { key: "approve", label: "Approve plan", next: "cloud-rails-code", action: "approve" },
            { key: "revise", label: "Revise plan", next: "revise-plan", action: "follow_up" },
            { key: "reject", label: "Stop run", action: "reject" }
          ],
          x: 340,
          y: 160
        },
        {
          id: "revise-plan",
          type: "follow_up",
          label: "Revise Plan",
          prompt: "Tell Qwen what to change in the plan. The next step will regenerate the plan before coding.",
          x: 560,
          y: 260
        },
        action_node.call("cloud-rails-code", "cloud-rails-code", 780),
        action_node.call("present-result", "present-sandbox-result", 1_000),
        action_node.call("open-change-request", "open-change-request", 1_220)
      ]

      edges = [
        { id: "draft-plan-review-plan", from: "draft-plan", to: "review-plan", condition: "success" },
        { id: "review-plan-cloud-rails-code", from: "review-plan", to: "cloud-rails-code", condition: "choice:approve" },
        { id: "review-plan-revise-plan", from: "review-plan", to: "revise-plan", condition: "choice:revise" },
        { id: "revise-plan-draft-plan", from: "revise-plan", to: "draft-plan", condition: "answered" },
        { id: "cloud-rails-code-present-result", from: "cloud-rails-code", to: "present-result", condition: "success" },
        { id: "present-result-open-change-request", from: "present-result", to: "open-change-request", condition: "success" }
      ]

      { nodes: nodes, edges: edges }
    end

    def default_for(key)
      case key
      when "run-tests"
        { command: "if [ -x bin/rails ]; then bin/rails test; else bundle exec rails test; fi" }
      when "security-scan"
        { command: "bin/brakeman --no-pager" }
      when "update-dependencies"
        { command: "if [ -f Gemfile.lock ]; then bundle update --patch; else bundle lock && bundle update --patch; fi" }
      when "codex-plan-dependencies"
        {
          command: "Inspect the repository dependency files and prepare a concise dependency update plan. Do not edit files."
        }
      when "codex-update-dependencies"
        {
          command: "Update Ruby dependencies safely. If Gemfile.lock exists, run bundle update --patch. If Gemfile.lock is missing, create it with bundle lock, then run bundle update --patch. Verify the Rails environment or tests, and summarize changed files."
        }
      when "verify-typescript-sandbox"
        { command: "npm install --no-audit --no-fund && npm run verify && npm run xmode:agent-change -- Bender" }
      when "verify-ruby-rails-sandbox"
        { command: "ruby scripts/xmode_hello_world.rb \"Print Hello World in README\"" }
      when "cloud-rails-code"
        { command: "ruby scripts/xmode_hello_world.rb \"Print Hello World in README\"" }
      else
        {}
      end
    end

    def runtime_for(key)
      return { shell: true, real_sandbox_in_demo: true, fixture: "hello-world-typescript" } if key == "verify-typescript-sandbox"
      return { shell: true, real_sandbox_in_demo: true, fixture: "hello-world-rails", language: "ruby", framework: "rails" } if key == "verify-ruby-rails-sandbox"
      return cloud_rails_runtime if key == "cloud-rails-code"
      return codex_cli_runtime(sandbox_mode: "read-only") if key == "codex-plan-dependencies"
      return codex_cli_runtime(sandbox_mode: "workspace-write") if key == "codex-update-dependencies"
      return { "mode" => "live", "temperature" => 0.1, "max_tokens" => 360, "num_predict" => 360 } if key == "present-sandbox-result"
      return { "mode" => "live", "temperature" => 0.1, "max_tokens" => 420, "num_predict" => 420 } if key == "local-model-plan"

      key.in?(%w[run-tests security-scan update-dependencies open-change-request]) ? { shell: true } : {}
    end

    def output_schema_for(key)
      return PLAN_OUTPUT_SCHEMA if key == "local-model-plan"
      return PRESENT_RESULT_OUTPUT_SCHEMA if key == "present-sandbox-result"

      DEFAULT_OUTPUT_SCHEMA
    end

    def cloud_rails_runtime
      {
        shell: true,
        real_sandbox_in_demo: true,
        fixture: "hello-world-rails",
        language: "ruby",
        framework: "rails",
        sandbox_kind: "cloud_vm",
        runner_mode: "cloud_worker",
        docker_image: ExecutionEnvironment::DEFAULT_RUBY_DOCKER_IMAGE,
        agent_command_template: "codex exec --model ${XMODE_CODE_MODEL:-configured-profile} --sandbox workspace-write --skip-git-repo-check - < .xmode/plan.md"
      }
    end

    def codex_cli_runtime(sandbox_mode:)
      {
        shell: true,
        real_sandbox_in_demo: true,
        language: "ruby",
        framework: "rails",
        sandbox_kind: "cloud_vm",
        runner_mode: "cloud_worker",
        docker_image: ExecutionEnvironment::DEFAULT_RUBY_DOCKER_IMAGE,
        agent_command_template: "codex exec --model ${XMODE_CODE_MODEL:-configured-profile} --sandbox #{sandbox_mode} --skip-git-repo-check - < .xmode/plan.md"
      }
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
      when "cloud-sandbox-implementation"
        "Run coding in the hosted sandbox worker. Keep the user's browser local to approvals and review while all repository mutation happens in the cloud sandbox worktree."
      else
        "Follow the action objective, preserve context, validate the result, and record output."
      end
    end

    def skill_best_practices_for(key)
      case key
      when "software-implementation"
        [ "Start from an explicit objective.", "Prefer the repository's existing patterns.", "Every code-changing run must produce a Change Request." ]
      when "cloud-sandbox-implementation"
        [ "Never edit the user's local checkout.", "Run code-changing commands in a hosted sandbox worktree.", "Expose logs, changed files, diff, and Change Request evidence before merging." ]
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
      when "local-model-plan"
        "Use the self-hosted local model to draft a bounded implementation plan for {{issue}} {{issue_title}} in {{project}}."
      when "code"
        "Implement the approved plan for {{issue}} {{issue_title}} in {{project}}."
      when "run-tests"
        "Verify the current change for {{issue}} {{issue_title}} in {{project}}."
      when "verify-typescript-sandbox"
        "Verify that xmode can clone, inspect, and modify the {{project}} TypeScript sandbox fixture."
      when "verify-ruby-rails-sandbox"
        "Verify that xmode can clone, inspect, and modify the {{project}} Ruby on Rails sandbox fixture."
      when "cloud-rails-code"
        "Implement the approved plan for {{issue}} {{issue_title}} inside a hosted Rails cloud sandbox for {{project}}."
      when "codex-plan-dependencies"
        "Use Oracle Codex CLI to prepare a dependency update plan for {{project}} without changing files."
      when "codex-update-dependencies"
        "Use Oracle Codex CLI to update dependencies for {{project}} inside the cloud sandbox."
      when "present-sandbox-result"
        "Explain the cloud sandbox output, changed files, tests, and review package for {{issue}} {{issue_title}}."
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
      when "local-model-plan"
        "Send objective and run context to the private local model, require structured JSON back, and keep coding behind sandbox and Change Request steps."
      when "code"
        "Confirm the approved plan, edit only relevant files, run focused checks, capture artifacts, and prepare for review."
      when "run-tests"
        "Choose the narrowest meaningful test command first, run it, capture output, and report failures as structured evidence."
      when "verify-typescript-sandbox"
        "Clone the fixture repository, install dependencies, run the verification script, generate a predictable fixture diff, and record sandbox evidence."
      when "verify-ruby-rails-sandbox"
        "Clone the Rails fixture repository, run the Ruby sandbox script, generate a predictable README/service/test diff, and record sandbox evidence."
      when "cloud-rails-code"
        "Clone the Rails repository in the cloud worker, apply the approved agent change, capture stdout/stderr, changed files, and a sandbox diff, and leave the local checkout untouched."
      when "codex-plan-dependencies"
        "Clone the repository in the Oracle worker, ask Codex CLI to inspect dependency files, produce a concise update plan, and make no repository edits."
      when "codex-update-dependencies"
        "Clone the repository in the Oracle worker, run Codex CLI against the approved dependency objective, update dependency state, capture stdout/stderr, changed files, and diff evidence."
      when "present-sandbox-result"
        "Read the previous planning and cloud sandbox evidence, then produce a concise reviewer-facing result summary with changed files, tests, and next review action."
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
      when "cloud-rails-code"
        "Run only inside the hosted sandbox worktree. Use the approved plan as the contract, capture evidence, and never mutate the user's local checkout."
      when "codex-plan-dependencies"
        "Run Codex CLI in read-only mode on the Oracle worker and produce planning evidence before any dependency file is changed."
      when "codex-update-dependencies"
        "Run Codex CLI in the hosted sandbox worktree. Keep dependency edits scoped and package changed files into a Change Request."
      when "present-sandbox-result"
        "Present the result as a review brief. Do not claim additional code changes; summarize only evidence produced by earlier sandbox steps."
      else
        "Use the objective and plan fields as the action contract. If objective is unclear, produce or request a better plan before doing irreversible work."
      end
    end

    def action_best_practices_for(key)
      base = [ "Use structured input and output.", "Keep the action scoped to its objective.", "Record evidence for the next pipeline step." ]
      return base + [ "Do not change the main checkout directly.", "Every code change should end in a new Change Request." ] if key.in?(%w[code cloud-rails-code codex-update-dependencies update-dependencies open-change-request])
      return base + [ "Run Codex in read-only mode.", "Make the dependency plan visible before approval." ] if key == "codex-plan-dependencies"
      return base + [ "Make approval choices explicit: approve, revise, trigger, or reject." ] if key.in?(%w[verify-plan manual-approval review-diff])
      return base + [ "Reference only actual sandbox evidence.", "Keep the summary concise enough for review." ] if key == "present-sandbox-result"

      base
    end
  end
end

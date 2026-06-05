require "rails_helper"
require "open3"
require "tmpdir"

RSpec.describe Pipelines::Runner do
  it "pauses for manual approvals and stores snapshots" do
    workspace = Workspace.create!(name: "Spec")
    skill = workspace.skill_definitions.create!(
      key: "manual-decision",
      name: "Manual Decision",
      category: "manual",
      instructions: "Pause for review.",
      input_schema: { type: "object" },
      output_schema: { type: "object" },
      best_practices: [ "Make the decision explicit." ]
    )
    action = workspace.action_definitions.create!(
      key: "manual-approval",
      name: "Manual Approval",
      category: "manual",
      provider: "manual",
      skill_definition: skill,
      objective_template: "Approve {{issue}} {{issue_title}}.",
      plan_template: "Review the plan and choose approve or revise.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "approval",
      name: "Approval",
      graph: { nodes: [ { id: "node-1", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    expect(run.reload.status).to eq("waiting_for_approval")
    expect(run.approvals.where(status: "pending").count).to eq(1)
    expect(run.pipeline_snapshot).to include("key" => "approval")
    expect(run.action_run_steps.first.input_json).to include(
      "objective" => "Approve  .",
      "plan" => "Review the plan and choose approve or revise."
    )
    expect(run.action_run_steps.first.input_json.dig("skill", "name")).to eq("Manual Decision")
  end

  it "pauses on decision nodes and records a pending structured chat question" do
    workspace = Workspace.create!(name: "Spec")
    pipeline = workspace.pipeline_definitions.create!(
      key: "interactive",
      name: "Interactive",
      graph: {
        nodes: [
          {
            id: "clarify",
            type: "decision",
            label: "Clarify objective",
            question: "How should the pipeline handle missing acceptance criteria?",
            choices: [
              { key: "infer", label: "Infer from issue", next: "finish" },
              { key: "stop", label: "Stop run" }
            ]
          },
          { id: "finish", type: "follow_up", label: "Final note", prompt: "Add a note before continuing." }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    expect(run.reload.status).to eq("waiting_for_input")
    expect(run.action_run_steps.first.status).to eq("waiting_for_input")
    expect(run.run_messages.pending.first).to have_attributes(
      kind: "choice_question",
      content: "How should the pipeline handle missing acceptance criteria?"
    )
    expect(run.run_messages.pending.first.choices.map { |choice| choice["key"] }).to include("infer", "stop")
  end

  it "records sandbox sessions for local shell actions" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "echo",
      name: "Echo",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf ok" },
      objective_template: "Run echo.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "shell",
      name: "Shell",
      graph: { nodes: [ { id: "echo", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    sandbox = run.sandbox_sessions.first
    expect(run.reload.status).to eq("completed")
    expect(workspace.audit_events.pluck(:action)).to include("pipeline_run.started", "pipeline_run.completed")
    expect(run.usage_recorded_at).to be_present
    expect(workspace.billing_subscriptions.last.automation_minutes_used).to eq(1)
    expect(sandbox).to have_attributes(kind: "docker_worktree", status: "ready")
    expect(sandbox.execution_environment).to have_attributes(kind: "ephemeral_sandbox", status: "ready")
    expect(sandbox.worktree_path).to include("storage/runs")
  end

  it "stores planning local shell stdout as structured plan output" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "codex-plan-dependencies",
      name: "Codex Plan Dependencies",
      category: "planning",
      provider: "local_shell",
      defaults: { "command" => "printf 'Dependency update plan:\\n\\n1. Inspect Gemfile.\\n2. Approve before edits.\\n'" },
      objective_template: "Plan dependency updates.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "dependency-plan",
      name: "Dependency Plan",
      graph: { nodes: [ { id: "plan", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    step = run.action_run_steps.first
    expect(run.reload.status).to eq("completed")
    expect(step.output_json).to include(
      "summary" => "Dependency update plan",
      "status" => "planned",
      "provider" => "local_shell"
    )
    expect(step.output_json.fetch("provider_mode")).to be_present
    expect(step.output_json.fetch("plan")).to include("Inspect Gemfile", "Approve before edits")
    expect(step.output_json.fetch("next_steps")).to include("Review the generated plan.")
    expect(step.output_json.fetch("acceptance_checks").join("\n")).to include("Change Request")
    expect(run.run_artifacts.pluck(:name)).to include("stdout.log", "stderr.log", "output.json")
  end

  it "captures token usage from JSON lines emitted by a shell agent" do
    workspace = Workspace.create!(name: "Spec")
    action = workspace.action_definitions.create!(
      key: "codex-json-usage",
      name: "Codex JSON Usage",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf '%s\\n' '{\"usage\":{\"input_tokens\":7,\"output_tokens\":5,\"total_tokens\":12}}'" },
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "json-usage",
      name: "JSON Usage",
      graph: { nodes: [ { id: "usage", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline)

    described_class.call(run)

    expect(run.reload.status).to eq("completed")
    expect(run.action_run_steps.first.output_json).to include(
      "provider_usage" => { "input_tokens" => 7, "output_tokens" => 5, "total_tokens" => 12 }
    )
  end

  it "opens a Change Request automatically when a local shell step changes files" do
    Dir.mktmpdir("xmode-source-repo") do |repo_path|
      system!("git", "init", chdir: repo_path)
      system!("git", "checkout", "-B", "main", chdir: repo_path)
      File.write(File.join(repo_path, "README.md"), "fixture\n")
      system!("git", "add", "README.md", chdir: repo_path)
      system!(
        "git",
        "-c",
        "user.name=xmode",
        "-c",
        "user.email=xmode@example.invalid",
        "commit",
        "-m",
        "Initial fixture",
        chdir: repo_path
      )

      workspace = Workspace.create!(name: "Spec")
      team = workspace.teams.create!(name: "Engineering", key: "eng")
      project = workspace.projects.create!(
        team: team,
        title: "Fixture",
        key: "fixture",
        repository_url: repo_path
      )
      issue = workspace.issues.create!(
        team: team,
        project: project,
        title: "Change fixture",
        description: "Create a controlled code change.",
        priority: "medium"
      )
      action = workspace.action_definitions.create!(
        key: "change-file",
        name: "Change File",
        category: "coding",
        provider: "local_shell",
        defaults: { "command" => "printf generated > generated.txt" },
        objective_template: "Change the fixture.",
        input_schema: { type: "object" },
        output_schema: { type: "object" }
      )
      pipeline = workspace.pipeline_definitions.create!(
        key: "change-without-cr-step",
        name: "Change Without CR Step",
        graph: { nodes: [ { id: "change", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
      )
      run = workspace.pipeline_runs.create!(
        pipeline_definition: pipeline,
        project: project,
        issue: issue,
        trigger: "manual"
      )

      described_class.call(run)

      change_request = run.reload.change_request
      expect(run.status).to eq("completed")
      expect(change_request).to have_attributes(
        issue: issue,
        provider: "local",
        branch_name: "xmode/#{issue.identifier.downcase}-#{run.id}",
        status: "draft"
      )
      expect(change_request.checks).to include(
        "branch_status" => "created",
        "branch_name" => "xmode/#{issue.identifier.downcase}-#{run.id}"
      )
      expect(change_request.checks.fetch("commit_sha")).to match(/\A[0-9a-f]{40}\z/)
      expect(change_request.checks.fetch("changed_files").map { |entry| entry.fetch("path") }).to include("generated.txt")
      expect(run.run_artifacts.pluck(:name)).to include("change-request-package.json")
      expect(run.run_logs.pluck(:message).join("\n")).to include("Code-changing output created a Change Request")
    end
  end

  it "creates visible demo sandbox files for local shell actions" do
    workspace = Workspace.create!(name: "Demo", demo: true)
    action = workspace.action_definitions.create!(
      key: "run-tests",
      name: "Run Tests",
      category: "verification",
      provider: "local_shell",
      objective_template: "Run tests.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "demo-shell",
      name: "Demo Shell",
      graph: { nodes: [ { id: "tests", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "demo_agent")

    described_class.call(run)

    sandbox = run.sandbox_sessions.first
    expect(Sandboxes::FileInventory.call(sandbox).map { |entry| entry.fetch(:path) }).to include("README.md", "agent-notes.md")
  end

  def system!(*command, chdir:)
    return if system(*command, chdir: chdir, out: File::NULL, err: File::NULL)

    raise "Command failed: #{command.join(' ')}"
  end
end

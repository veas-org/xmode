require "rails_helper"
require "open3"

RSpec.describe "TypeScript sandbox fixture" do
  it "clones the local hello-world-typescript repo and records a predictable sandbox diff" do
    fixture_path = Rails.root.join("..", "hello-world-typescript").expand_path
    skip "hello-world-typescript fixture repository is not available" unless fixture_path.join(".git").directory?

    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    project = workspace.projects.create!(
      team: team,
      title: "Sandbox Verification",
      key: "sandbox-verification",
      repository_url: fixture_path.to_s
    )
    action = workspace.action_definitions.create!(
      key: "mock-agent-change",
      name: "Mock Agent Change",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "node scripts/mock-agent-change.mjs Bender" },
      objective_template: "Create a predictable fixture change.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "typescript-sandbox-fixture",
      name: "TypeScript Sandbox Fixture",
      graph: {
        nodes: [
          { id: "mock-agent-change", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      trigger: "manual",
      input_context: { "objective" => "Verify a TypeScript sandbox fixture." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)

    expect(run.reload.status).to eq("completed")
    expect(step.output_json).to include(
      "status" => "completed",
      "changed_files_count" => 2,
      "diff_artifact" => "sandbox-diff.patch",
      "changed_files_artifact" => "changed-files.json"
    )
    expect(step.output_json.fetch("changed_files").map { |entry| entry.fetch("path") }).to contain_exactly("CHANGELOG.xmode.md", "src/generated-greeting.ts")
    expect(sandbox_path.join("src/generated-greeting.ts")).to exist
    expect(sandbox_path.join("CHANGELOG.xmode.md")).to exist
    expect(run.run_artifacts.pluck(:name)).to include("stdout.log", "stderr.log", "changed-files.json", "sandbox-diff.patch", "output.json")
    expect(run.run_logs.pluck(:message).join("\n")).to include("Created a mock agent change for Bender.")
  end

  it "runs through the built-in demo sandbox verification pipeline and opens a Change Request package" do
    fixture_path = Rails.root.join("..", "hello-world-typescript").expand_path
    skip "hello-world-typescript fixture repository is not available" unless fixture_path.join(".git").directory?

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    project = workspace.projects.find_by!(key: "sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-6")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-sandbox-fixture")

    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: { "objective" => "Run the TypeScript sandbox fixture through the real local sandbox path." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)

    expect(run.reload.status).to eq("completed")
    expect(step.action_definition.key).to eq("verify-typescript-sandbox")
    expect(step.output_json).to include("status" => "completed", "changed_files_count" => 2)
    expect(sandbox_path.join("src/generated-greeting.ts")).to exist
    expect(sandbox_path.join("CHANGELOG.xmode.md")).to exist
    expect(run.run_artifacts.pluck(:name)).to include("output.json", "changed-files.json", "sandbox-diff.patch", "agent-report.md")
    expect(run.change_request).to have_attributes(
      issue: issue,
      provider: "local",
      branch_name: "xmode/ops-6-#{run.id}",
      status: "draft"
    )
    expect(run.change_request.repository_connection.url).to eq(project.repository_url)
    expect(run.change_request.checks).to include(
      "branch_status" => "created",
      "branch_name" => "xmode/ops-6-#{run.id}",
      "sandbox_worktree_path" => sandbox.worktree_path
    )
    expect(run.change_request.checks.fetch("commit_sha")).to match(/\A[0-9a-f]{40}\z/)
    expect(run.change_request.checks.fetch("changed_files").map { |entry| entry.fetch("path") }).to contain_exactly("CHANGELOG.xmode.md", "src/generated-greeting.ts")
    branch_name, = Open3.capture2("git", "branch", "--show-current", chdir: sandbox_path.to_s)
    head_sha, = Open3.capture2("git", "rev-parse", "HEAD", chdir: sandbox_path.to_s)
    status, = Open3.capture2("git", "status", "--short", chdir: sandbox_path.to_s)
    expect(branch_name.strip).to eq("xmode/ops-6-#{run.id}")
    expect(head_sha.strip).to eq(run.change_request.checks.fetch("commit_sha"))
    expect(status).to be_blank
    expect(run.run_artifacts.pluck(:name)).to include("change-request-package.json")
    expect(run.run_logs.pluck(:message).join("\n")).to include("Repository cloned into sandbox", "Created a mock agent change for Bender.")
  end
end

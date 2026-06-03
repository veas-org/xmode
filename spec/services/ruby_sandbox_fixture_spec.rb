require "rails_helper"
require "open3"

RSpec.describe "Ruby Rails sandbox fixture" do
  it "clones the local hello-world-rails repo and records a predictable sandbox diff" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    project = workspace.projects.create!(
      team: team,
      title: "Rails Sandbox Verification",
      key: "rails-sandbox-verification",
      repository_url: fixture_path.to_s
    )
    action = workspace.action_definitions.create!(
      key: "mock-rails-agent-change",
      name: "Mock Rails Agent Change",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "ruby scripts/xmode_hello_world.rb \"Print Hello World in README\"" },
      objective_template: "Create a predictable Rails fixture change.",
      input_schema: { type: "object" },
      output_schema: { type: "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "ruby-rails-sandbox-fixture",
      name: "Ruby Rails Sandbox Fixture",
      graph: {
        nodes: [
          { id: "mock-rails-agent-change", action_key: action.key, action_id: action.id, label: action.name }
        ],
        edges: []
      }
    )
    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      trigger: "manual",
      input_context: { "objective" => "Verify a Ruby Rails sandbox fixture." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)
    changed_paths = step.output_json.fetch("changed_files").map { |entry| entry.fetch("path") }
    stdout = File.read(run.run_artifacts.find_by!(name: "stdout.log").path)

    expect(run.reload.status).to eq("completed")
    expect(step.output_json).to include(
      "status" => "completed",
      "changed_files_count" => 3,
      "diff_artifact" => "sandbox-diff.patch",
      "changed_files_artifact" => "changed-files.json"
    )
    expect(changed_paths).to contain_exactly("README.md", "app/services/hello_world_printer.rb", "test/services/hello_world_printer_test.rb")
    expect(sandbox_path.join("README.md").read).to include("Hello World Feature Flow", "Hello World from Rails sandbox")
    expect(sandbox_path.join("app/services/hello_world_printer.rb")).to exist
    expect(sandbox_path.join("test/services/hello_world_printer_test.rb")).to exist
    expect(stdout).to include("Information flow: objective captured, implementation generated, evidence written")
    expect(stdout).to include("Hello World from Rails sandbox")
    expect(run.run_artifacts.pluck(:name)).to include("stdout.log", "stderr.log", "changed-files.json", "sandbox-diff.patch", "output.json")
  end

  it "runs through the built-in demo Rails sandbox verification pipeline and opens a Change Request package" do
    fixture_path = Rails.root.join("..", "hello-world-rails").expand_path
    skip "hello-world-rails fixture repository is not available" unless fixture_path.join(".git").directory?

    seed = Demo::PlanetExpressSeeder.call
    workspace = seed.workspace
    project = workspace.projects.find_by!(key: "rails-sandbox-verification")
    issue = workspace.issues.find_by!(identifier: "OPS-7")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-rails-sandbox-fixture")

    run = workspace.pipeline_runs.create!(
      pipeline_definition: pipeline,
      project: project,
      issue: issue,
      trigger: "manual",
      input_context: { "objective" => "Run the Rails sandbox fixture through the real local sandbox path." }
    )

    Pipelines::Runner.call(run)

    step = run.action_run_steps.first
    sandbox = run.sandbox_sessions.first
    sandbox_path = Pathname.new(sandbox.worktree_path)
    changed_paths = run.change_request.checks.fetch("changed_files").map { |entry| entry.fetch("path") }

    expect(run.reload.status).to eq("completed")
    expect(step.action_definition.key).to eq("verify-ruby-rails-sandbox")
    expect(step.output_json).to include("status" => "completed", "changed_files_count" => 3)
    expect(sandbox.execution_environment).to have_attributes(language: "ruby", framework: "rails")
    expect(sandbox_path.join("README.md").read).to include("Hello World Feature Flow")
    expect(sandbox_path.join("app/services/hello_world_printer.rb")).to exist
    expect(sandbox_path.join("test/services/hello_world_printer_test.rb")).to exist
    expect(run.run_artifacts.pluck(:name)).to include("output.json", "changed-files.json", "sandbox-diff.patch", "change-request-package.json")
    expect(run.change_request).to have_attributes(
      issue: issue,
      provider: "local",
      branch_name: "xmode/ops-7-#{run.id}",
      status: "draft"
    )
    expect(run.change_request.repository_connection.url).to eq(project.repository_url)
    expect(run.change_request.checks).to include(
      "branch_status" => "created",
      "branch_name" => "xmode/ops-7-#{run.id}",
      "sandbox_worktree_path" => sandbox.worktree_path
    )
    expect(run.change_request.checks.fetch("commit_sha")).to match(/\A[0-9a-f]{40}\z/)
    expect(changed_paths).to contain_exactly("README.md", "app/services/hello_world_printer.rb", "test/services/hello_world_printer_test.rb")
    branch_name, = Open3.capture2("git", "branch", "--show-current", chdir: sandbox_path.to_s)
    head_sha, = Open3.capture2("git", "rev-parse", "HEAD", chdir: sandbox_path.to_s)
    status, = Open3.capture2("git", "status", "--short", chdir: sandbox_path.to_s)
    expect(branch_name.strip).to eq("xmode/ops-7-#{run.id}")
    expect(head_sha.strip).to eq(run.change_request.checks.fetch("commit_sha"))
    expect(status).to be_blank
    expect(run.run_logs.pluck(:message).join("\n")).to include("Repository cloned into sandbox", "Hello World from Rails sandbox")
  end
end

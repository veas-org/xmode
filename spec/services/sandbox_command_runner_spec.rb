require "rails_helper"
require "open3"

RSpec.describe Sandboxes::CommandRunner do
  it "runs a command inside the sandbox and records audit evidence" do
    workspace = Workspace.create!(name: "Spec")
    run = workspace.pipeline_runs.create!(trigger: "manual")
    step = run.action_run_steps.create!(name: "Run Tests", position: 0)
    sandbox_root = Rails.root.join("storage", "runs", run.id.to_s, step.id.to_s, "sandbox")
    sandbox_root.mkpath
    sandbox = run.sandbox_sessions.create!(
      workspace: workspace,
      action_run_step: step,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: sandbox_root.to_s
    )
    command = sandbox.sandbox_commands.create!(
      pipeline_run: run,
      action_run_step: step,
      command: "printf hello"
    )

    described_class.call(command)

    expect(command.reload).to have_attributes(status: "completed", stdout: "hello", exit_status: 0)
    expect(run.run_logs.last.message).to include("Sandbox command completed")
    expect(run.run_messages.last).to have_attributes(role: "tool", kind: "sandbox_event")
  ensure
    FileUtils.rm_rf(sandbox_root) if defined?(sandbox_root)
  end

  it "runs interactive sandbox commands inside the configured Docker image" do
    workspace = Workspace.create!(name: "Spec")
    project = workspace.projects.create!(team: workspace.teams.create!(name: "Engineering"), title: "Docker Project")
    environment = workspace.execution_environments.create!(
      project: project,
      name: "#{project.key} sandbox",
      kind: "ephemeral_sandbox",
      status: "ready",
      metadata: {
        "runner_mode" => "docker",
        "docker_image" => "ghcr.io/acme/xmode-agent:1"
      }
    )
    run = workspace.pipeline_runs.create!(project: project, trigger: "manual")
    step = run.action_run_steps.create!(name: "Run Tests", position: 0)
    sandbox_root = Rails.root.join("storage", "runs", run.id.to_s, step.id.to_s, "sandbox")
    sandbox_root.mkpath
    sandbox = run.sandbox_sessions.create!(
      workspace: workspace,
      project: project,
      execution_environment: environment,
      action_run_step: step,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: sandbox_root.to_s
    )
    command = sandbox.sandbox_commands.create!(
      pipeline_run: run,
      action_run_step: step,
      command: "npm test"
    )
    status = instance_double(Process::Status, success?: true, exitstatus: 0)
    allow(Open3).to receive(:capture3).and_return([ "docker ok", "", status ])

    described_class.call(command)

    expect(Open3).to have_received(:capture3).with(
      "docker",
      "run",
      "--rm",
      "-v",
      "#{sandbox_root}:/workspace",
      "-w",
      "/workspace",
      "ghcr.io/acme/xmode-agent:1",
      "sh",
      "-s",
      stdin_data: "npm test"
    )
    expect(command.reload).to have_attributes(status: "completed", stdout: "docker ok", exit_status: 0)
  ensure
    FileUtils.rm_rf(sandbox_root) if defined?(sandbox_root)
  end

  it "fails safely when the worktree is outside run storage" do
    workspace = Workspace.create!(name: "Spec")
    run = workspace.pipeline_runs.create!(trigger: "manual")
    sandbox = run.sandbox_sessions.create!(
      workspace: workspace,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: Rails.root.to_s
    )
    command = sandbox.sandbox_commands.create!(pipeline_run: run, command: "pwd")

    described_class.call(command)

    expect(command.reload.status).to eq("failed")
    expect(command.stderr).to include("Sandbox worktree is not available")
  end
end

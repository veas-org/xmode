require "rails_helper"

RSpec.describe Sandboxes::FileInventory do
  it "lists files inside the run storage sandbox and ignores git metadata" do
    workspace = Workspace.create!(name: "Spec")
    run = workspace.pipeline_runs.create!(trigger: "manual")
    step = run.action_run_steps.create!(name: "Run Tests", position: 0)
    sandbox_root = Rails.root.join("storage", "runs", run.id.to_s, step.id.to_s, "sandbox")
    sandbox_root.join(".git").mkpath
    sandbox_root.join("app").mkpath
    sandbox_root.join("README.md").write("sandbox")
    sandbox_root.join("app", "models.rb").write("model")
    sandbox = run.sandbox_sessions.create!(
      workspace: workspace,
      action_run_step: step,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: sandbox_root.to_s
    )

    entries = described_class.call(sandbox)

    expect(entries.map { |entry| entry.fetch(:path) }).to include("README.md", "app", "app/models.rb")
    expect(entries.map { |entry| entry.fetch(:path) }).not_to include(".git")
  ensure
    FileUtils.rm_rf(sandbox_root) if defined?(sandbox_root)
  end

  it "does not expose paths outside run storage" do
    workspace = Workspace.create!(name: "Spec")
    run = workspace.pipeline_runs.create!(trigger: "manual")
    sandbox = run.sandbox_sessions.create!(
      workspace: workspace,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: Rails.root.to_s
    )

    expect(described_class.call(sandbox)).to eq([])
  end
end

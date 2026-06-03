require "rails_helper"

RSpec.describe Demo::PlanetExpressSeeder do
  it "seeds an idempotent Bender demo workspace" do
    first = described_class.call
    second = described_class.call

    workspace = second.workspace
    user = second.user

    expect(first.workspace.id).to eq(workspace.id)
    expect(user.email).to eq("bender.demo@xmode.local")
    expect(user).to be_demo
    expect(workspace).to be_demo
    expect(workspace.name).to eq("Planet Express")
    expect(workspace.projects.pluck(:key)).to include("delivery-automation", "ship-reliability", "route-optimization", "sandbox-verification", "rails-sandbox-verification")
    expect(workspace.projects.find_by!(key: "sandbox-verification").repository_url).to include("hello-world-typescript")
    expect(workspace.projects.find_by!(key: "rails-sandbox-verification").repository_url).to include("hello-world-rails")
    expect(workspace.repository_connections.find_by!(name: "Sandbox Verification").provider).to be_in(%w[local github])
    expect(workspace.repository_connections.find_by!(name: "Rails Sandbox Verification").provider).to be_in(%w[local github])
    expect(workspace.issues.pluck(:identifier)).to include("OPS-1", "OPS-4", "OPS-6", "OPS-7")
    expect(workspace.action_definitions.find_by!(key: "verify-typescript-sandbox").runtime_config).to include("real_sandbox_in_demo" => true)
    expect(workspace.action_definitions.find_by!(key: "verify-ruby-rails-sandbox").runtime_config).to include("real_sandbox_in_demo" => true, "language" => "ruby", "framework" => "rails")
    sandbox_pipeline = workspace.pipeline_definitions.find_by!(key: "verify-sandbox-fixture")
    expect(sandbox_pipeline.graph.fetch("nodes").map { |node| node.fetch("action_key") }).to eq(%w[verify-typescript-sandbox open-change-request])
    rails_pipeline = workspace.pipeline_definitions.find_by!(key: "verify-rails-sandbox-fixture")
    expect(rails_pipeline.graph.fetch("nodes").map { |node| node.fetch("action_key") }).to eq(%w[verify-ruby-rails-sandbox open-change-request])
    expect(workspace.execution_environments.find_by!(project: workspace.projects.find_by!(key: "rails-sandbox-verification")).docker_image).to eq(ExecutionEnvironment::DEFAULT_RUBY_DOCKER_IMAGE)
    expect(workspace.events.find_by(title: "Critical moon delivery failed")).to be_present
    expect(workspace.schedules.where(kind: "recurring").count).to eq(1)
    expect(workspace.pipeline_runs.where(trigger: "demo").count).to eq(1)
    expect(workspace.pipeline_runs.where(trigger: "schedule", status: "completed").count).to eq(1)
    expect(workspace.change_requests.find_by(branch_name: "xmode/ship-dependencies-demo")).to be_present
    expect(workspace.change_requests.find_by(branch_name: "xmode/ops-4-demo")).to be_present
  end

  it "refreshes existing built-in pipeline definitions when catalog defaults change" do
    described_class.call
    workspace = Workspace.find_by!(slug: "planet-express")
    pipeline = workspace.pipeline_definitions.find_by!(key: "verify-sandbox-fixture")
    pipeline.update!(
      graph: {
        nodes: [
          { id: "old", action_key: "verify-typescript-sandbox", label: "Old" }
        ],
        edges: []
      }
    )

    described_class.call

    expect(pipeline.reload.graph.fetch("nodes").map { |node| node.fetch("action_key") }).to eq(%w[verify-typescript-sandbox open-change-request])
    expect(workspace.pipeline_definitions.find_by!(key: "verify-rails-sandbox-fixture").graph.fetch("nodes").map { |node| node.fetch("action_key") }).to eq(%w[verify-ruby-rails-sandbox open-change-request])
  end
end

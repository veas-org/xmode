require "rails_helper"

RSpec.describe ExecutionEnvironment, type: :model do
  it "defaults to a cloud worker runner with the standard Docker image available" do
    workspace = Workspace.create!(name: "Spec")
    environment = workspace.execution_environments.build(
      name: "Spec sandbox",
      kind: "ephemeral_sandbox",
      status: "ready"
    )

    expect(environment.runner_mode).to eq("cloud_worker")
    expect(environment).to be_cloud_worker
    expect(environment).not_to be_docker
    expect(environment.runner_label).to eq("Cloud worker")
    expect(environment.docker_image).to eq(ExecutionEnvironment::DEFAULT_NODE_DOCKER_IMAGE)
  end

  it "supports project sandbox Docker images" do
    workspace = Workspace.create!(name: "Spec")
    environment = workspace.execution_environments.build(
      name: "Spec sandbox",
      kind: "ephemeral_sandbox",
      status: "ready",
      metadata: {
        "runner_mode" => "docker",
        "docker_image" => "ghcr.io/acme/xmode-agent:1"
      }
    )

    expect(environment.runner_mode).to eq("docker")
    expect(environment).to be_docker
    expect(environment.docker_image).to eq("ghcr.io/acme/xmode-agent:1")
  end

  it "infers Ruby Rails sandbox defaults from the project repository" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    project = workspace.projects.create!(
      team: team,
      title: "Rails Sandbox Verification",
      repository_url: "https://github.com/m9rc1n/hello-world-rails.git"
    )
    environment = workspace.execution_environments.build(
      project: project,
      name: "Rails sandbox",
      kind: "ephemeral_sandbox",
      status: "ready",
      metadata: ExecutionEnvironment.default_metadata_for(project)
    )

    expect(environment.language).to eq("ruby")
    expect(environment.framework).to eq("rails")
    expect(environment.docker_image).to eq(ExecutionEnvironment::DEFAULT_RUBY_DOCKER_IMAGE)
  end
end

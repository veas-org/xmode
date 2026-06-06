require "rails_helper"

RSpec.describe "Project detail", type: :request do
  it "shows project operating context, automation, and Change Request evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    project = workspace.projects.find_by!(key: "delivery-automation")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Project command surface")
    expect(response.body).to include("Repository")
    expect(response.body).to include("https://github.com/planet-express/delivery-automation.git")
    expect(response.body).to include("Project workbench")
    expect(response.body).to include("Run sandbox")
    expect(response.body).to include("Issue flow")
    expect(response.body).to include("Recent runs")
    expect(response.body).to include("Sandboxed agent")
    expect(response.body).to include("Change Requests")
    expect(response.body).to include("xmode/ops-4-demo")
  end

  it "shows project-level scheduled pipelines" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    project = workspace.projects.find_by!(key: "ship-reliability")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Scheduled pipelines")
    expect(response.body).to include("Update Dependencies")
    expect(response.body).to include("0 9 * * 1")
  end

  it "renders recent sandbox runs without distincting over json columns" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    user = User.create!(name: "Ada", email: "ada-project-sandbox@example.com", password: "password123")
    workspace.memberships.create!(user: user, role: "owner")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture")
    pipeline = workspace.pipeline_definitions.create!(
      key: "verify-sandbox-fixture",
      name: "Verify Sandbox Fixture",
      version: "1.0.0",
      graph: { "nodes" => [], "edges" => [] }
    )
    run = workspace.pipeline_runs.create!(
      project: project,
      pipeline_definition: pipeline,
      status: "completed",
      trigger: "sandbox",
      input_context: { "objective" => "Verify project sandbox" },
      pipeline_snapshot: { "graph" => { "nodes" => [] } }
    )
    2.times do |index|
      SandboxSession.create!(
        workspace: workspace,
        project: project,
        pipeline_run: run,
        kind: "docker_worktree",
        status: "ready",
        metadata: { "index" => index }
      )
    end

    post login_path, params: { email: user.email, password: "password123" }
    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recent sandboxes")
    expect(response.body).to include("Verify Sandbox Fixture")
  end

  it "starts a project sandbox run with the configured execution environment" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    user = User.create!(name: "Ada", email: "ada@example.com", password: "password123")
    workspace.memberships.create!(user: user, role: "owner")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture", repository_url: "/tmp/hello-world-typescript")
    action = workspace.action_definitions.create!(
      key: "verify-typescript-sandbox",
      name: "Verify TypeScript Sandbox",
      version: "1.0.0",
      category: "verification",
      provider: "local_shell",
      defaults: { "command" => "printf ok" },
      input_schema: { "type" => "object" },
      output_schema: { "type" => "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "verify-sandbox-fixture",
      name: "Verify Sandbox Fixture",
      version: "1.0.0",
      graph: {
        "nodes" => [
          { "id" => "verify", "type" => "action", "action_key" => action.key }
        ],
        "edges" => []
      }
    )
    workspace.execution_environments.create!(
      project: project,
      kind: "ephemeral_sandbox",
      name: "#{project.key} sandbox",
      status: "ready",
      metadata: {
        "runner_mode" => "docker",
        "docker_image" => "ghcr.io/acme/xmode-agent:1"
      }
    )

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post run_sandbox_project_path(project), params: { objective: "Verify the sandbox fixture" }
    }.to change(workspace.pipeline_runs, :count).by(1)

    run = workspace.pipeline_runs.order(:created_at).last
    expect(response).to redirect_to(pipeline_run_path(run))
    expect(run.pipeline_definition).to eq(pipeline)
    expect(run.trigger).to eq("sandbox")
    expect(run.input_context).to include(
      "objective" => "Verify the sandbox fixture",
      "runner_mode" => "docker",
      "docker_image" => "ghcr.io/acme/xmode-agent:1"
    )
  end

  it "uses the cloud Rails implementation pipeline for Ruby Rails projects" do
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering")
    user = User.create!(name: "Ada", email: "ada-rails@example.com", password: "password123")
    workspace.memberships.create!(user: user, role: "owner")
    project = workspace.projects.create!(team: team, title: "Rails Sandbox Verification", repository_url: "/tmp/hello-world-rails")
    action = workspace.action_definitions.create!(
      key: "local-model-plan",
      name: "Local Model Plan",
      version: "1.0.0",
      category: "planning",
      provider: "local_model",
      input_schema: { "type" => "object" },
      output_schema: { "type" => "object" }
    )
    pipeline = workspace.pipeline_definitions.create!(
      key: "cloud-rails-implement-issue",
      name: "Cloud Rails Implement Issue",
      version: "1.0.0",
      required_context: { "cloud_sandbox" => true, "repository" => true, "issue" => true },
      graph: {
        "nodes" => [
          { "id" => "plan", "type" => "action", "action_key" => action.key }
        ],
        "edges" => []
      }
    )

    post login_path, params: { email: user.email, password: "password123" }
    post run_sandbox_project_path(project), params: { objective: "Verify the Rails sandbox fixture" }

    run = workspace.pipeline_runs.order(:created_at).last
    expect(response).to redirect_to(pipeline_run_path(run))
    expect(run.pipeline_definition).to eq(pipeline)
    expect(run.input_context).to include(
      "objective" => "Verify the Rails sandbox fixture",
      "plan" => "Use Codex to draft and revise the plan, wait for approval, code only inside the cloud sandbox, then present the result and Change Request evidence.",
      "runner_mode" => "cloud_worker",
      "docker_image" => ExecutionEnvironment::DEFAULT_RUBY_DOCKER_IMAGE
    )
  end
end

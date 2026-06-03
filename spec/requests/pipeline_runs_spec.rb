require "rails_helper"

RSpec.describe "Pipeline run detail", type: :request do
  it "shows the automation queue as an operating ledger" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get pipeline_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Run ledger")
    expect(response.body).to include("Queue health")
    expect(response.body).to include("Evidence chain")
    expect(response.body).to include("Run weekly dependency maintenance")
    expect(response.body).to include("xmode/ship-dependencies-demo")
    expect(response.body).to include("Objective captured")
    expect(Nokogiri::HTML(response.body).css("a.app-btn[href='/pipelines']")).to be_empty
  end

  it "shows approvals, snapshots, logs, artifacts, and Change Request context" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    run = workspace.pipeline_runs.find_by!(trigger: "demo")
    repository = workspace.repository_connections.first
    change_request = workspace.change_requests.create!(
      repository_connection: repository,
      pipeline_run: run,
      issue: run.issue,
      provider: repository.provider,
      branch_name: "xmode/#{run.issue.identifier.downcase}-audit",
      title: "#{run.issue.identifier}: Audit run evidence",
      status: "draft"
    )

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Run contract")
    expect(response.body).to include("Approvals")
    expect(response.body).to include("Verify Plan")
    expect(response.body).to include("Pending")
    expect(response.body).to include("Change Request")
    expect(response.body).to include("Sandboxed agent")
    expect(response.body).to include(change_request.branch_name)
    expect(response.body).to include("Snapshot")
    expect(response.body).to include("Pipeline started")
    expect(response.body).to include("agent-report.md")
    expect(response.body).not_to include(">Resume</span>")
  end

  it "renders sandbox files for a local shell run" do
    user = User.create!(name: "Owner", email: "owner-sandbox-files@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
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
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")
    Pipelines::Runner.call(run)

    post login_path, params: { email: user.email, password: "password123" }
    get pipeline_run_path(run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sandboxes")
    expect(response.body).to include("Workspace sandbox")
    expect(response.body).to include("README.md")
  end

  it "runs and renders sandbox terminal commands" do
    user = User.create!(name: "Owner", email: "owner-sandbox-terminal@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
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
      key: "shell-terminal",
      name: "Shell Terminal",
      graph: { nodes: [ { id: "echo", action_key: action.key, action_id: action.id, label: action.name } ], edges: [] }
    )
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, trigger: "manual")
    Pipelines::Runner.call(run)
    sandbox = run.sandbox_sessions.first

    post login_path, params: { email: user.email, password: "password123" }
    post pipeline_run_sandbox_session_commands_path(run, sandbox), params: { command: "printf terminal" }

    expect(response).to redirect_to(pipeline_run_path(run))
    follow_redirect!
    expect(response.body).to include("Terminal")
    expect(response.body).to include("$ printf terminal")
    expect(response.body).to include("terminal")
    expect(run.sandbox_commands.last).to have_attributes(status: "completed", stdout: "terminal")
  end
end

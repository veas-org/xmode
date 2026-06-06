require "rails_helper"

RSpec.describe "Sandbox sessions", type: :request do
  it "renders open sandboxes and lets users stop one" do
    user, workspace, team = create_workspace_owner("owner-sandbox-sessions@example.com")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture", repository_url: "/tmp/fixture")
    pipeline = workspace.pipeline_definitions.create!(key: "sandbox", name: "Sandbox Pipeline")
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, user: user, project: project, trigger: "sandbox", status: "completed")
    environment = workspace.execution_environments.create!(
      project: project,
      kind: "ephemeral_sandbox",
      name: "Fixture sandbox",
      status: "ready",
      metadata: { "runner_mode" => "docker", "docker_image" => "ruby:3.4-bookworm" }
    )
    sandbox_root = Rails.root.join("storage", "runs", run.id.to_s, "sandbox")
    sandbox_root.mkpath
    sandbox_root.join("README.md").write("sandbox")
    sandbox = workspace.sandbox_sessions.create!(
      pipeline_run: run,
      project: project,
      execution_environment: environment,
      kind: "docker_worktree",
      status: "ready",
      worktree_path: sandbox_root.to_s
    )

    post login_path, params: { email: user.email, password: "password123" }
    get sandbox_sessions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sandboxes")
    expect(response.body).to include("Active sandboxes")
    expect(response.body).to include("Fixture sandbox")
    expect(response.body).to include("Your usage 1/3")

    get sandbox_session_path(sandbox)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sandbox lineage")
    expect(response.body).to include("README.md")

    post stop_sandbox_session_path(sandbox)

    expect(response).to redirect_to(sandbox_session_path(sandbox))
    expect(sandbox.reload.status).to eq("destroyed")
    expect(sandbox.finished_at).to be_present
  ensure
    FileUtils.rm_rf(sandbox_root) if defined?(sandbox_root)
  end

  it "starts a sandbox from the global sandbox page" do
    user, workspace, team = create_workspace_owner("owner-start-sandbox@example.com")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture", repository_url: "/tmp/hello-world-typescript")
    create_typescript_sandbox_pipeline(workspace)

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post sandbox_sessions_path, params: { project_id: project.id, objective: "Verify the global sandbox start path" }
    }.to change(workspace.pipeline_runs, :count).by(1)

    run = workspace.pipeline_runs.order(:created_at).last
    expect(response).to redirect_to(pipeline_run_path(run))
    expect(run).to have_attributes(user: user, project: project, trigger: "sandbox")
    expect(run.input_context).to include("objective" => "Verify the global sandbox start path")
  end

  it "enforces the per-user open sandbox limit" do
    allow(SandboxSession).to receive(:open_limit).and_return(1)

    user, workspace, team = create_workspace_owner("owner-sandbox-limit@example.com")
    project = workspace.projects.create!(team: team, title: "Sandbox Fixture", repository_url: "/tmp/hello-world-typescript")
    pipeline = create_typescript_sandbox_pipeline(workspace)
    run = workspace.pipeline_runs.create!(pipeline_definition: pipeline, user: user, project: project, trigger: "sandbox", status: "completed")
    workspace.sandbox_sessions.create!(pipeline_run: run, project: project, kind: "docker_worktree", status: "ready")

    post login_path, params: { email: user.email, password: "password123" }

    expect {
      post sandbox_sessions_path, params: { project_id: project.id, objective: "Start another sandbox" }
    }.not_to change(workspace.pipeline_runs, :count)

    expect(response).to redirect_to(sandbox_sessions_path)
    follow_redirect!
    expect(response.body).to include("Open sandbox limit reached")
  end

  def create_workspace_owner(email)
    user = User.create!(name: "Owner", email: email, password: "password123")
    workspace = Workspace.create!(name: "Spec #{email.parameterize.first(8)}")
    team = workspace.teams.create!(name: "Engineering")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    [ user, workspace, team ]
  end

  def create_typescript_sandbox_pipeline(workspace)
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
    workspace.pipeline_definitions.create!(
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
  end
end

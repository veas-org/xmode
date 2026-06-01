require "rails_helper"

RSpec.describe "Demo agent operations", type: :request do
  it "creates a demo issue and runs a sandboxed agent pipeline from the command center form" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    workspace = Workspace.find_by!(slug: "planet-express")
    pipeline = workspace.pipeline_definitions.find_by!(key: "implement-issue")
    project = workspace.projects.find_by!(key: "delivery-automation")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    post run_pipeline_path(pipeline), params: {
      project_id: project.id,
      input_context: {
        objective: "Implement retry handling for failed delivery webhooks"
      }
    }

    run = workspace.pipeline_runs.order(:created_at).last
    expect(response).to redirect_to(pipeline_run_path(run))
    expect(run.trigger).to eq("demo_agent")
    expect(run.issue.title).to eq("Implement retry handling for failed delivery webhooks")
    expect(run.reload.status).to eq("waiting_for_approval")
    expect(run.run_logs.pluck(:message).join("\n")).to include("Planet Express sandboxed agent started")
    expect(run.run_artifacts.pluck(:name)).to include("agent-report.md")
  end
end

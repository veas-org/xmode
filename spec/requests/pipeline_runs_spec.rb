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
end

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
end

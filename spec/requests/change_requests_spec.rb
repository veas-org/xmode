require "rails_helper"

RSpec.describe "Change Requests", type: :request do
  it "shows a Change Request as a review package with checks and run evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    change_request = workspace.change_requests.find_by!(branch_name: "xmode/ship-dependencies-demo")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Review package")
    expect(response.body).to include("Review readiness")
    expect(response.body).to include("Run evidence")
    expect(response.body).to include("Checks")
    expect(response.body).to include("Artifacts")
    expect(response.body).to include("Linked context")
    expect(response.body).to include(change_request.branch_name)
    expect(response.body).to include("tests")
    expect(response.body).to include("passed")
    expect(response.body).to include("update-dependencies-report.md")
    expect(response.body).to include("Update Dependencies")
    expect(response.body).to include("OPS-3")

    doc = Nokogiri::HTML(response.body)
    expect(doc.css("pre")).to be_empty
    expect(doc.css("a.app-btn-primary").map(&:text).join).not_to include("Open")
  end

  it "keeps manual Change Requests understandable without run evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    change_request = workspace.change_requests.find_by!(branch_name: "xmode/ops-4-demo")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get change_request_path(change_request)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No run evidence is attached yet")
    expect(response.body).to include("OPS-4")
    expect(response.body).to include("waiting_for_review")
  end
end

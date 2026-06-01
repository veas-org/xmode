require "rails_helper"

RSpec.describe "Cycles", type: :request do
  it "shows a cycle as a sprint operating surface" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    cycle = workspace.cycles.find_by!(name: "Delivery Sprint 3000")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get cycle_path(cycle)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sprint operating surface")
    expect(response.body).to include("Cycle brief")
    expect(response.body).to include("Cycle work")
    expect(response.body).to include("Cycle health")
    expect(response.body).to include("Objective, plan, goal")
    expect(response.body).to include("Automation evidence")
    expect(response.body).to include("OPS-1")
    expect(response.body).to include("Implement Issue")
    expect(response.body).to include("xmode/ops-4-demo")
    expect(response.body).to include("Superpower the delivery engineering loop")
    expect(response.body).to include("Implement Issue rollout plan")
    expect(response.body).not_to include("Cycle issues")

    doc = Nokogiri::HTML(response.body)
    panel_links = doc.css("a[data-turbo-frame='side_panel']")
    expect(panel_links.any? { |link| link["href"] == edit_cycle_path(cycle) && link["aria-label"] == "Edit cycle" }).to be(true)
    expect(panel_links.any? { |link| link["href"] == new_issue_path(cycle_id: cycle.id) && link["aria-label"] == "New issue" }).to be(true)
    expect(doc.css("a.linear-tab").map(&:text).join).not_to include("New issue")
  end
end

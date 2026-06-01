require "rails_helper"

RSpec.describe "Schedules", type: :request do
  it "shows a schedule as an operating record with target, action path, and evidence" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    schedule = workspace.schedules.find_by!(kind: "recurring")

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Schedule operating record")
    expect(response.body).to include("Trigger contract")
    expect(response.body).to include("Action path")
    expect(response.body).to include("Recent scheduled runs")
    expect(response.body).to include("Safety boundary")
    expect(response.body).to include("Target context")
    expect(response.body).to include("Update Dependencies")
    expect(response.body).to include("Ship Reliability")
    expect(response.body).to include("0 9 * * 1")
    expect(response.body).to include("New branch and Change Request")
    expect(response.body).to include("xmode/ship-dependencies-demo")
    expect(response.body).to include("update-dependencies-report.md")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(%(a[href="#{edit_schedule_path(schedule)}"][data-turbo-frame="side_panel"]))).to be_present
    expect(doc.css("a.app-btn-primary, button.app-btn-primary, input.app-btn-primary")).to be_empty
  end
end

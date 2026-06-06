require "rails_helper"

RSpec.describe "Automation workspace", type: :request do
  it "renders a consolidated queue, library, triggers, and sandbox surface" do
    Demo::PlanetExpressSeeder.call
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }

    get automations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Run, route, and review agent work")
    expect(response.body).to include("Needs attention")
    expect(response.body).to include("Recent runs")
    expect(response.body).to include(change_requests_path)

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(%(a.app-sidebar-link[href="#{automations_path}"]))).to be_present
    expect(doc.css(".app-sidebar-link").map(&:text).join(" ")).not_to include("Skills", "Actions", "Schedules")
    expect(doc.css(".automation-tabs a").map(&:text).join(" ")).to include("Queue", "Library", "Triggers", "Sandboxes")

    get automations_path(tab: "library")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reusable automation pieces")
    expect(response.body).to include("What can run")
    expect(response.body).to include("How steps execute")
    expect(response.body).to include("Guidance behind actions")
    expect(response.body).to include("Who performs work")
    expect(response.body).to include("How agents coordinate")
    expect(response.body).to include(pipelines_home_path)
    expect(response.body).to include(actions_home_path)
    expect(response.body).to include(skills_home_path)
    expect(response.body).to include(agent_swarm_runs_path)

    library_doc = Nokogiri::HTML(response.body)
    expect(library_doc.at_css(%(a[href="#{new_pipeline_path}"][data-turbo-frame="side_panel"]))).to be_present
    expect(library_doc.at_css(%(a[href="#{import_pipelines_path}"][data-turbo-frame="side_panel"]))).to be_present
    expect(library_doc.at_css(%(form[action="#{agent_swarm_runs_path}"] button[type="submit"]))).to be_present

    get automations_path(tab: "triggers")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Events and schedules")
    expect(response.body).to include("Routing rules")
    expect(response.body).to include("Signed intake")

    get automations_path(tab: "sandboxes")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Active sandboxes")
    expect(response.body).to include("Start sandbox")
  end
end

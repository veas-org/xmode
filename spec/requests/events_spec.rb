require "rails_helper"

RSpec.describe "Event inbox", type: :request do
  it "shows event routing rules and matched automation context" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Event intake")
    expect(response.body).to include("Latest events")
    expect(response.body).to include("Rules")
    expect(response.body).to include("Critical delivery exceptions")
    expect(response.body).to include("Handle Production Event")
    expect(response.body).to include("Critical moon delivery failed")
    expect(response.body).to include("1 rule")
    expect(response.body).to include("Event state")
    expect(response.body).to include("Event libraries")
    expect(response.body).to include("https://github.com/m9rc1n/xmode-events")
    expect(response.body).to include("@xmode/events")
    expect(response.body).to include("captureBug")
    expect(response.body).to include("capture_warning")
    expect(response.body).to include("/webhooks/events/#{workspace.slug}/{source}")
    expect(response.body).to include("Settings -> Integrations")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".ops-page")).to be_present
    expect(doc.at_css(%(dd.break-all[title*="/webhooks/events/#{workspace.slug}/{source}"]))).to be_present
    expect(doc.css(".linear-surface")).to be_empty
    expect(workspace.event_rules.count).to eq(1)
  end

  it "shows a structured event operating record with side-panel triage" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    event = workspace.events.find_by!(title: "Critical moon delivery failed")
    rule = workspace.event_rules.find_by!(name: "Critical delivery exceptions")

    workspace.pipeline_runs.create!(
      pipeline_definition: rule.pipeline_definition,
      event: event,
      trigger: "event_rule",
      input_context: { "event_id" => event.id, "rule_id" => rule.id }
    )

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Routing contract")
    expect(response.body).to include("Automation routing")
    expect(response.body).to include("Related execution evidence")
    expect(response.body).to include("Normalized fields")
    expect(response.body).to include("Payload fields")
    expect(response.body).to include("Routing timeline")
    expect(response.body).to include("Critical delivery exceptions")
    expect(response.body).to include("Handle Production Event")
    expect(response.body).to include("delivery-webhook")
    expect(response.body).to include("delivery.failed")
    expect(response.body).to include("Dark matter stabilizer")
    expect(response.body).to include("planet-express/delivery-automation")
    expect(response.body).to include("Add issue")
    expect(response.body).to include('data-turbo-frame="side_panel"')
    expect(response.body).not_to include("<pre")
    expect(response.body).not_to include("app-btn-primary")

    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css(".record-detail-layout.event-record-layout")).to be_present
    expect(doc.css(".record-panel")).to be_empty
  end
end

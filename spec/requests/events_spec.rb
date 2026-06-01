require "rails_helper"

RSpec.describe "Event inbox", type: :request do
  it "shows event routing rules and matched automation context" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Event inbox")
    expect(response.body).to include("Routing rules")
    expect(response.body).to include("Critical delivery exceptions")
    expect(response.body).to include("Handle Production Event")
    expect(response.body).to include("source: delivery-webhook")
    expect(response.body).to include("severity: critical")
    expect(response.body).to include("Critical moon delivery failed")
    expect(response.body).to include("1 rule")
    expect(response.body).to include("Event flow")
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
    expect(response.body).to include("Event operating record")
    expect(response.body).to include("Matched automation rules")
    expect(response.body).to include("Related automation runs")
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
  end
end

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
end

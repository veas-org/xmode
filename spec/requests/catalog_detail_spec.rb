require "rails_helper"

RSpec.describe "Catalog detail pages", type: :request do
  before do
    Demo::PlanetExpressSeeder.call
    @workspace = Workspace.find_by!(slug: "planet-express")
    @user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)
    post login_path, params: { email: @user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
  end

  it "shows action contracts without a raw snapshot dump" do
    action = @workspace.action_definitions.find_by!(key: "code")

    get action_path(action)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Action contract")
    expect(response.body).to include("Input contract")
    expect(response.body).to include("Output contract")
    expect(response.body).to include("Used by pipelines")
    expect(response.body).to include("Implement Issue")
    expect(response.body).to include("Fix Failing Build")
    expect(response.body).not_to include(JSON.pretty_generate(action.snapshot))
  end

  it "shows pipeline operating context without a raw graph panel" do
    pipeline = @workspace.pipeline_definitions.find_by!(key: "handle-production-event")

    get pipeline_path(pipeline)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Action graph")
    expect(response.body).to include("Run contract")
    expect(response.body).to include("Event rules")
    expect(response.body).to include("Critical delivery exceptions")
    expect(response.body).to include("Recent runs")
    expect(response.body).not_to include("Raw graph")
    expect(response.body).not_to include(JSON.pretty_generate(pipeline.graph))
  end
end

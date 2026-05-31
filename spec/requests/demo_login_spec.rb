require "rails_helper"

RSpec.describe "Demo login", type: :request do
  it "opens Bender's Planet Express workspace" do
    post demo_login_path(workspace: "planet-express")

    expect(response).to redirect_to(app_path)

    follow_redirect!
    expect(response.body).to include("Planet Express")
    expect(response.body).to include("Bender Bending Rodriguez")
    expect(response.body).to include("Demo workspace")
  end

  it "rejects unknown demo workspaces" do
    post demo_login_path(workspace: "unknown")

    expect(response).to redirect_to(login_path)
  end
end

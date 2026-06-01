require "rails_helper"

RSpec.describe "Billing", type: :request do
  it "shows the workspace commercial boundary, usage, and hosted readiness" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    user = User.find_by!(email: Demo::PlanetExpressSeeder::BENDER_EMAIL)

    post login_path, params: { email: user.email, password: Demo::PlanetExpressSeeder::PASSWORD }
    get billing_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("#{workspace.name} billing boundary")
    expect(response.body).to include("Current plan")
    expect(response.body).to include("Automation usage")
    expect(response.body).to include("Plan policy")
    expect(response.body).to include("Hosted readiness")
    expect(response.body).to include("Commercial boundary")
    expect(response.body).to include("Open-source core")
    expect(response.body).to include("Hosted SaaS")
    expect(response.body).to include("184/1000 minutes")
    expect(response.body).to include("Stripe customer")
    expect(response.body).to include("Subscription record")
    expect(response.body).to include("Synced")
    expect(response.body).not_to include("Pricing coming soon")

    doc = Nokogiri::HTML(response.body)
    expect(doc.css("a.app-btn-primary, button.app-btn-primary")).to be_empty
  end
end

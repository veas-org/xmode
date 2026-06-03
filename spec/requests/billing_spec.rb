require "rails_helper"
require "ostruct"

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
    expect(response.body).to include("Start hosted plan")
    expect(response.body).to include("Billing portal")
    expect(response.body).to include("Billing operations")
    expect(response.body).to include("184/1000 minutes")
    expect(response.body).to include("Stripe customer")
    expect(response.body).to include("Subscription record")
    expect(response.body).to include("Synced")
    expect(response.body).not_to include("Pricing coming soon")

    doc = Nokogiri::HTML(response.body)
    expect(doc.css("a.app-btn-primary, button.app-btn-primary")).to be_empty
  end

  it "redirects billing admins to Stripe checkout and portal sessions" do
    user = User.create!(name: "Owner", email: "owner-billing-actions@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec", stripe_customer_id: "cus_test")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    checkout_session = ApplicationService.success(url: "https://checkout.stripe.com/c/cs_test", session: OpenStruct.new(id: "cs_test"))
    portal_session = ApplicationService.success(url: "https://billing.stripe.com/p/session", session: OpenStruct.new(id: "bps_test"))
    allow(Billing::StripeCheckout).to receive(:call).and_return(checkout_session)
    allow(Billing::StripePortal).to receive(:call).and_return(portal_session)

    post login_path, params: { email: user.email, password: "password123" }

    post checkout_billing_path
    expect(response).to redirect_to("https://checkout.stripe.com/c/cs_test")
    expect(workspace.audit_events.last).to have_attributes(action: "billing.checkout_started", user: user)

    post portal_billing_path
    expect(response).to redirect_to("https://billing.stripe.com/p/session")
    expect(workspace.audit_events.last).to have_attributes(action: "billing.portal_opened", user: user)
  end
end

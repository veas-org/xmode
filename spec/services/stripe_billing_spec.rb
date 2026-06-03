require "rails_helper"
require "ostruct"

RSpec.describe "Stripe billing services" do
  around do |example|
    original_secret = ENV["STRIPE_SECRET_KEY"]
    original_price = ENV["STRIPE_TEAM_PRICE_ID"]
    ENV["STRIPE_SECRET_KEY"] = "sk_test_xmode"
    ENV["STRIPE_TEAM_PRICE_ID"] = "price_team"
    example.run
  ensure
    ENV["STRIPE_SECRET_KEY"] = original_secret
    ENV["STRIPE_TEAM_PRICE_ID"] = original_price
  end

  it "creates a checkout session with workspace metadata and seat quantity" do
    user = User.create!(name: "Owner", email: "owner-stripe-checkout@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")
    allow(Stripe::Checkout::Session).to receive(:create).and_return(
      OpenStruct.new(id: "cs_test", url: "https://checkout.stripe.com/c/cs_test")
    )

    result = Billing::StripeCheckout.call(
      workspace: workspace,
      user: user,
      success_url: "https://app.test/billing",
      cancel_url: "https://app.test/billing"
    )

    expect(result).to be_success
    expect(result.url).to eq("https://checkout.stripe.com/c/cs_test")
    expect(Stripe::Checkout::Session).to have_received(:create) do |payload|
      expect(payload).to include(
        mode: "subscription",
        success_url: "https://app.test/billing",
        cancel_url: "https://app.test/billing",
        client_reference_id: workspace.id.to_s
      )
      expect(payload[:metadata]).to eq(workspace_id: workspace.id.to_s)
      expect(payload[:line_items]).to eq([ { price: "price_team", quantity: 1 } ])
      expect(payload[:customer_email]).to eq(user.email)
    end
  end

  it "creates a portal session for connected Stripe customers" do
    workspace = Workspace.create!(name: "Spec", stripe_customer_id: "cus_test")
    allow(Stripe::BillingPortal::Session).to receive(:create).and_return(
      OpenStruct.new(id: "bps_test", url: "https://billing.stripe.com/p/session")
    )

    result = Billing::StripePortal.call(
      workspace: workspace,
      return_url: "https://app.test/billing"
    )

    expect(result).to be_success
    expect(result.url).to eq("https://billing.stripe.com/p/session")
    expect(Stripe::BillingPortal::Session).to have_received(:create).with(
      customer: "cus_test",
      return_url: "https://app.test/billing"
    )
  end
end

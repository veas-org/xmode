require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  around do |example|
    original_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV.delete("STRIPE_WEBHOOK_SECRET")
    example.run
  ensure
    ENV["STRIPE_WEBHOOK_SECRET"] = original_secret
  end

  it "syncs completed checkout sessions to workspace billing state" do
    user = User.create!(name: "Owner", email: "owner-stripe-webhook@example.com", password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: "owner")

    post stripe_webhooks_path, params: {
      type: "checkout.session.completed",
      data: {
        object: {
          client_reference_id: workspace.id.to_s,
          metadata: { workspace_id: workspace.id.to_s },
          customer: "cus_test",
          subscription: "sub_test",
          payment_status: "paid"
        }
      }
    }.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    subscription = workspace.billing_subscriptions.find_by!(stripe_subscription_id: "sub_test")
    expect(response).to have_http_status(:ok)
    expect(workspace.reload).to have_attributes(stripe_customer_id: "cus_test", billing_plan: "team")
    expect(subscription).to have_attributes(plan: "team", status: "active", seats: 1)
  end

  it "accepts current Stripe subscription statuses" do
    workspace = Workspace.create!(name: "Spec", stripe_customer_id: "cus_test")

    post stripe_webhooks_path, params: {
      type: "customer.subscription.updated",
      data: {
        object: {
          id: "sub_unpaid",
          customer: "cus_test",
          status: "unpaid",
          current_period_end: 1.hour.from_now.to_i
        }
      }
    }.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    subscription = workspace.billing_subscriptions.find_by!(stripe_subscription_id: "sub_unpaid")
    expect(response).to have_http_status(:ok)
    expect(subscription.status).to eq("unpaid")
  end
end

module Billing
  class StripeCheckout < ApplicationService
    def self.call(workspace:, user:, success_url:, cancel_url:)
      new(workspace: workspace, user: user, success_url: success_url, cancel_url: cancel_url).call
    end

    def initialize(workspace:, user:, success_url:, cancel_url:)
      @workspace = workspace
      @user = user
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      return self.class.failure("Stripe secret key is not configured.") if stripe_secret_key.blank?
      return self.class.failure("Stripe team price is not configured.") if team_price_id.blank?

      Stripe.api_key = stripe_secret_key
      session = Stripe::Checkout::Session.create(checkout_payload)
      self.class.success(url: session.url, session: session)
    rescue Stripe::StripeError => e
      self.class.failure(e.message)
    end

    private

    def checkout_payload
      payload = {
        mode: "subscription",
        success_url: @success_url,
        cancel_url: @cancel_url,
        client_reference_id: @workspace.id.to_s,
        metadata: { workspace_id: @workspace.id.to_s },
        subscription_data: { metadata: { workspace_id: @workspace.id.to_s } },
        line_items: [
          {
            price: team_price_id,
            quantity: [ @workspace.memberships.count, 1 ].max
          }
        ]
      }
      if @workspace.stripe_customer_id.present?
        payload[:customer] = @workspace.stripe_customer_id
      else
        payload[:customer_email] = @user.email
      end
      payload
    end

    def stripe_secret_key
      ENV["STRIPE_SECRET_KEY"].to_s.strip
    end

    def team_price_id
      ENV["STRIPE_TEAM_PRICE_ID"].to_s.strip.presence || ENV["STRIPE_PRICE_ID"].to_s.strip.presence
    end
  end
end

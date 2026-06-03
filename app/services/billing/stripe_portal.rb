module Billing
  class StripePortal < ApplicationService
    def self.call(workspace:, return_url:)
      new(workspace: workspace, return_url: return_url).call
    end

    def initialize(workspace:, return_url:)
      @workspace = workspace
      @return_url = return_url
    end

    def call
      return self.class.failure("Stripe secret key is not configured.") if stripe_secret_key.blank?
      return self.class.failure("Stripe customer is not connected.") if @workspace.stripe_customer_id.blank?

      Stripe.api_key = stripe_secret_key
      session = Stripe::BillingPortal::Session.create(
        customer: @workspace.stripe_customer_id,
        return_url: @return_url
      )
      self.class.success(url: session.url, session: session)
    rescue Stripe::StripeError => e
      self.class.failure(e.message)
    end

    private

    def stripe_secret_key
      ENV["STRIPE_SECRET_KEY"].to_s.strip
    end
  end
end

class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    event = stripe_event
    case event.type
    when "customer.subscription.created", "customer.subscription.updated"
      upsert_subscription(event.data.object)
    when "customer.subscription.deleted"
      cancel_subscription(event.data.object)
    end
    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError => e
    render json: { error: e.message }, status: :bad_request
  end

  private

  def stripe_event
    payload = request.raw_post
    secret = ENV["STRIPE_WEBHOOK_SECRET"]
    return Stripe::Event.construct_from(JSON.parse(payload)) if secret.blank?

    Stripe::Webhook.construct_event(payload, request.env["HTTP_STRIPE_SIGNATURE"], secret)
  end

  def upsert_subscription(subscription)
    workspace = Workspace.find_by(stripe_customer_id: subscription.customer)
    return unless workspace

    workspace.billing_subscriptions.find_or_initialize_by(stripe_subscription_id: subscription.id).tap do |record|
      record.plan = workspace.billing_plan
      record.status = subscription.status
      record.current_period_end = Time.at(subscription.current_period_end) if subscription.current_period_end
      record.seats = workspace.memberships.count
      record.save!
    end
  end

  def cancel_subscription(subscription)
    BillingSubscription.find_by(stripe_subscription_id: subscription.id)&.update!(status: "canceled")
  end
end

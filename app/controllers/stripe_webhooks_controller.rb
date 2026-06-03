class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    event = stripe_event
    case event.type
    when "checkout.session.completed"
      complete_checkout_session(event.data.object)
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
      record.plan = hosted_plan_for(workspace)
      record.status = normalized_subscription_status(subscription.status)
      record.current_period_end = Time.at(subscription.current_period_end) if subscription.current_period_end
      record.seats = workspace.memberships.count
      record.save!
    end
  end

  def complete_checkout_session(session)
    workspace = Workspace.find_by(id: session_workspace_id(session))
    return unless workspace

    workspace.update!(
      stripe_customer_id: session.customer.presence || workspace.stripe_customer_id,
      billing_plan: "team"
    )
    return if session.subscription.blank?

    workspace.billing_subscriptions.find_or_initialize_by(stripe_subscription_id: subscription_id(session.subscription)).tap do |record|
      record.plan = "team"
      record.status = session.payment_status == "paid" ? "active" : "incomplete"
      record.seats = workspace.memberships.count
      record.save!
    end
  end

  def cancel_subscription(subscription)
    BillingSubscription.find_by(stripe_subscription_id: subscription.id)&.update!(status: "canceled")
  end

  def session_workspace_id(session)
    session.metadata.to_h["workspace_id"].presence || session.client_reference_id
  end

  def subscription_id(subscription)
    subscription.respond_to?(:id) ? subscription.id : subscription.to_s
  end

  def hosted_plan_for(workspace)
    workspace.billing_plan == "community" ? "team" : workspace.billing_plan
  end

  def normalized_subscription_status(status)
    status.to_s.in?(BillingSubscription::STATUSES) ? status.to_s : "inactive"
  end
end

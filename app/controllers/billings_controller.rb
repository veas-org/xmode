class BillingsController < AuthenticatedController
  def show
    @subscription = current_workspace.billing_subscriptions.order(created_at: :desc).first ||
      current_workspace.billing_subscriptions.create!(plan: current_workspace.billing_plan, status: "inactive", seats: current_workspace.memberships.count)
    @seat_count = current_workspace.memberships.count
    @billing_admin_count = current_workspace.memberships.where(role: %w[owner admin]).count
    @run_count = current_workspace.pipeline_runs.count
    @active_run_count = current_workspace.pipeline_runs.where(status: %w[queued running waiting_for_approval]).count
    @change_request_count = current_workspace.change_requests.count
    @repository_count = current_workspace.repository_connections.count
    @plan_rows = plan_rows
    @usage_limit = automation_minutes_limit_for(@subscription.plan)
    @usage_percent = usage_percent
    @readiness_rows = readiness_rows
  end

  private

  def plan_rows
    [
      [
        "Community",
        "Self-hosted AGPL core for project management, skills, actions, pipelines, and Change Requests.",
        "Open source"
      ],
      [
        "Team",
        "Hosted collaboration, managed runners, usage metering, billing, and supportable demo workspaces.",
        "Hosted SaaS"
      ],
      [
        "Enterprise",
        "Custom retention, private deployment support, audit requirements, SSO-ready account controls, and procurement.",
        "Commercial"
      ]
    ]
  end

  def readiness_rows
    [
      [ "Stripe customer", current_workspace.stripe_customer_id.present? ? "Connected" : "Not connected" ],
      [ "Subscription record", @subscription.stripe_subscription_id.present? ? "Synced" : "Local scaffold" ],
      [ "Billing admins", count_label(@billing_admin_count, "member") ],
      [ "Repositories", count_label(@repository_count, "connection") ],
      [ "Automation ledger", count_label(@run_count, "run") ],
      [ "Change Requests", count_label(@change_request_count, "record") ]
    ]
  end

  def automation_minutes_limit_for(plan)
    case plan
    when "team" then 1_000
    when "enterprise" then nil
    else 120
    end
  end

  def usage_percent
    return 0 if @usage_limit.blank?

    [ (@subscription.automation_minutes_used.to_f / @usage_limit * 100).round, 100 ].min
  end

  def count_label(count, noun)
    "#{count} #{noun.pluralize(count)}"
  end
end

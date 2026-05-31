class BillingsController < AuthenticatedController
  def show
    @subscription = current_workspace.billing_subscriptions.order(created_at: :desc).first ||
      current_workspace.billing_subscriptions.create!(plan: current_workspace.billing_plan, status: "inactive", seats: current_workspace.memberships.count)
  end
end

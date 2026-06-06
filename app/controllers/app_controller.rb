class AppController < AuthenticatedController
  def show
    @issues = current_workspace.issues.includes(:team, :project, :issue_status, :assignee).order(updated_at: :desc).limit(8)
    @projects = current_workspace.projects.includes(:team, :issues).order(updated_at: :desc).limit(6)
    @runs = current_workspace.pipeline_runs
      .includes(:pipeline_definition, :issue, :project, :event, :change_request, :run_artifacts)
      .order(created_at: :desc)
      .limit(8)
      .to_a
    @events = current_workspace.events.order(created_at: :desc).limit(6)
    @attention_runs = @runs.select { |run| run.status.in?(%w[waiting_for_approval waiting_for_input failed]) }.first(5)
    @approval_run = @attention_runs.find { |run| run.status == "waiting_for_approval" }
    @recent_change_requests = current_workspace.change_requests.includes(:issue, :repository_connection).order(updated_at: :desc).limit(4)
    @command_counts = {
      waiting: current_workspace.pipeline_runs.where(status: "waiting_for_approval").count,
      active: current_workspace.pipeline_runs.where(status: %w[queued running waiting_for_input]).count,
      failed: current_workspace.pipeline_runs.where(status: %w[failed canceled]).count,
      change_requests: current_workspace.change_requests.count
    }
    @demo_agent_pipeline = current_workspace.pipeline_definitions.find_by(key: "implement-issue") if current_workspace.demo?
    @demo_agent_projects = current_workspace.projects.order(:title) if current_workspace.demo?
    @demo_agent_objective = "Implement retry handling for failed delivery webhooks" if current_workspace.demo?
  end
end

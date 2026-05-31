class AppController < AuthenticatedController
  def show
    @issues = current_workspace.issues.includes(:team, :project, :issue_status).order(updated_at: :desc).limit(8)
    @projects = current_workspace.projects.includes(:team, :issues).order(updated_at: :desc).limit(6)
    @runs = current_workspace.pipeline_runs.order(created_at: :desc).limit(6)
    @events = current_workspace.events.order(created_at: :desc).limit(6)
    @operating_counts = {
      objectives: current_workspace.objectives.count,
      plans: current_workspace.plan_records.count,
      skills: current_workspace.skill_definitions.count,
      actions: current_workspace.action_definitions.count,
      runs: current_workspace.pipeline_runs.count,
      change_requests: current_workspace.change_requests.count
    }
    @demo_agent_pipeline = current_workspace.pipeline_definitions.find_by(key: "implement-issue") if current_workspace.demo?
    @demo_agent_projects = current_workspace.projects.order(:title) if current_workspace.demo?
  end
end

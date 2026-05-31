class SavedViewsController < AuthenticatedController
  def index
    @views = current_workspace.saved_views.includes(:team).order(:name)
    @view_rows = @views.map do |view|
      {
        view: view,
        count: count_for(view),
        path: path_for(view),
        icon: icon_for(view)
      }
    end
  end

  def show
    view = current_workspace.saved_views.find(params[:id])
    redirect_to path_for(view)
  end

  private

  def count_for(view)
    scope = current_workspace.issues
    scope = scope.where(team: view.team) if view.team

    case view.view_type
    when "my_issues"
      scope.where(assignee: current_user).count
    when "active_cycle"
      view.team ? scope.where(cycle: view.team.cycles.where(status: "active")).count : 0
    when "backlog"
      scope.joins(:issue_status).where(issue_statuses: { category: "backlog" }).count
    when "roadmap"
      current_workspace.projects.count
    when "automation_queue"
      current_workspace.pipeline_runs.count
    else
      scope.count
    end
  end

  def path_for(view)
    case view.view_type
    when "inbox"
      issues_path(view: "inbox")
    when "my_issues"
      issues_path(view: "my")
    when "active_cycle"
      issues_path(view: "active_cycle")
    when "backlog"
      issues_path(view: "backlog")
    when "roadmap"
      projects_path
    when "automation_queue"
      pipeline_runs_path
    else
      issues_path
    end
  end

  def icon_for(view)
    case view.view_type
    when "inbox" then "inbox"
    when "my_issues" then "user-circle"
    when "active_cycle" then "calendar"
    when "roadmap" then "folder"
    when "automation_queue" then "workflow"
    else "list-filter"
    end
  end
end

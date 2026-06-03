class SavedViewsController < AuthenticatedController
  ISSUE_VIEW_TYPES = %w[inbox my_issues backlog active_cycle].freeze
  VIEW_ORDER = {
    "inbox" => 0,
    "my_issues" => 1,
    "backlog" => 2,
    "active_cycle" => 3,
    "roadmap" => 4,
    "automation_queue" => 5
  }.freeze

  before_action :set_saved_view, only: :show

  def index
    load_view_rows
    @view_counts = {
      total: @view_rows.size,
      issue_views: @view_rows.count { |row| row.fetch(:view).view_type.in?(ISSUE_VIEW_TYPES) },
      roadmap: @view_rows.count { |row| row.dig(:view).view_type == "roadmap" },
      automation: @view_rows.count { |row| row.dig(:view).view_type == "automation_queue" }
    }
    @view_tree = build_view_tree(@view_rows)
    @primary_view_row = @view_rows.find { |row| row.fetch(:view).view_type == "inbox" } || @view_rows.first
    @sibling_view_rows = sibling_rows_for(@primary_view_row)
  end

  def show
    load_view_rows
    @view_row = row_for(@saved_view)
    @view_description = description_for(@saved_view)
    @source_path = source_path_for(@saved_view)
    @scope_label = @saved_view.team&.name || current_workspace.name
    @sibling_view_rows = sibling_rows_for(@view_row)

    case @saved_view.view_type
    when "roadmap"
      @projects = current_workspace.projects.includes(:team, :issues).order(updated_at: :desc)
    when "automation_queue"
      @runs = current_workspace.pipeline_runs.includes(:pipeline_definition, :issue, :project).order(created_at: :desc)
    else
      @issues = issue_scope_for(@saved_view).includes(:team, :project, :cycle, :issue_status, :assignee).order(updated_at: :desc)
    end
  end

  private

  def set_saved_view
    @saved_view = current_workspace.saved_views.includes(:team).find(params[:id])
  end

  def load_view_rows
    @views = current_workspace.saved_views.includes(:team).order(:team_id, :name)
    @view_rows = @views.map { |view| row_for(view) }
  end

  def build_view_tree(rows)
    rows.group_by { |row| row.fetch(:view).team }.sort_by { |team, _team_rows| team&.name.to_s }.map do |team, team_rows|
      {
        key: team ? "team-#{team.id}" : "workspace",
        label: team&.name || current_workspace.name,
        subtitle: team ? "#{current_workspace.name} team" : "Workspace views",
        count: team_rows.size,
        rows: sort_view_rows(team_rows)
      }
    end
  end

  def sort_view_rows(rows)
    rows.sort_by { |row| [ view_position(row.fetch(:view)), row.fetch(:view).name ] }
  end

  def sibling_rows_for(row)
    return [] unless row

    view = row.fetch(:view)
    sort_view_rows(@view_rows.select { |candidate| candidate.fetch(:view).team_id == view.team_id })
  end

  def view_position(view)
    VIEW_ORDER.fetch(view.view_type, VIEW_ORDER.length)
  end

  def row_for(view)
    {
      view: view,
      count: count_for(view),
      source_path: source_path_for(view),
      icon: icon_for(view),
      description: description_for(view)
    }
  end

  def count_for(view)
    case view.view_type
    when "roadmap"
      current_workspace.projects.count
    when "automation_queue"
      current_workspace.pipeline_runs.count
    else
      issue_scope_for(view).count
    end
  end

  def issue_scope_for(view)
    scope = current_workspace.issues
    scope = scope.where(team: view.team) if view.team

    case view.view_type
    when "my_issues"
      scope.where(assignee: current_user)
    when "active_cycle"
      view.team ? scope.where(cycle: view.team.cycles.where(status: "active")) : scope.none
    when "backlog"
      scope.joins(:issue_status).where(issue_statuses: { category: "backlog" })
    else
      scope
    end
  end

  def source_path_for(view)
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

  def description_for(view)
    case view.view_type
    when "inbox"
      "Incoming work across the team, ordered by recent movement."
    when "my_issues"
      "Work assigned to you, scoped to the selected team."
    when "active_cycle"
      "Issues committed to the team cycle currently in progress."
    when "backlog"
      "Unstarted work that still needs prioritization, assignment, or planning."
    when "roadmap"
      "Project-level delivery tracks with issue counts and repository context."
    when "automation_queue"
      "Pipeline runs, approvals, artifacts, and automation status in one queue."
    else
      "Workspace view using the saved filter contract."
    end
  end
end

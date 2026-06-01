class CyclesController < AuthenticatedController
  before_action :set_cycle, only: %i[show edit update]

  def index
    @cycles = current_workspace.cycles.includes(:team).order(starts_on: :desc, created_at: :desc)
  end

  def show
    @issues = @cycle.issues
      .includes(:issue_status, :project, :assignee, :labels, :pipeline_runs, :change_requests)
      .order(updated_at: :desc)
    issue_list = @issues.to_a
    issue_ids = issue_list.map(&:id)
    project_ids = issue_list.filter_map(&:project_id).uniq

    @issue_total = issue_list.size
    @completed_issues = issue_list.count { |issue| issue.issue_status&.category == "completed" }
    @cycle_completion = @issue_total.zero? ? 0 : ((@completed_issues.to_f / @issue_total) * 100).round
    @estimate_total = issue_list.sum { |issue| issue.estimate.to_i }
    @days_remaining = @cycle.ends_on ? (@cycle.ends_on - Date.current).to_i : nil
    @cycle_window_label = [ @cycle.starts_on || "No start", @cycle.ends_on || "No end" ].join(" - ")
    @status_rows = status_rows_for(issue_list)
    @priority_counts = Issue::PRIORITIES.index_with { |priority| issue_list.count { |issue| issue.priority == priority } }.select { |_priority, count| count.positive? }

    @cycle_runs = current_workspace.pipeline_runs
      .includes(:pipeline_definition, :issue, :change_request)
      .where(issue_id: issue_ids)
      .order(created_at: :desc)
      .limit(5)
    @cycle_change_requests = current_workspace.change_requests
      .includes(:issue, :repository_connection, :pipeline_run)
      .where(issue_id: issue_ids)
      .order(updated_at: :desc)
      .limit(5)
    @cycle_objectives = current_workspace.objectives
      .where(objectiveable_type: "Project", objectiveable_id: project_ids)
      .order(updated_at: :desc)
      .limit(3)
    @cycle_plans = current_workspace.plan_records
      .where(plannable_type: "Project", plannable_id: project_ids)
      .order(updated_at: :desc)
      .limit(3)
    @cycle_goals = current_workspace.goals
      .where(goalable_type: "Project", goalable_id: project_ids)
      .order(updated_at: :desc)
      .limit(3)
  end

  def new
    @cycle = current_workspace.cycles.new(team: current_team)
  end

  def create
    @cycle = current_workspace.cycles.new(cycle_params)
    @cycle.team ||= current_team
    if @cycle.save
      redirect_to @cycle, notice: "Cycle created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cycle.update(cycle_params)
      redirect_to @cycle, notice: "Cycle updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_cycle
    @cycle = current_workspace.cycles.find(params[:id])
  end

  def cycle_params
    params.require(:cycle).permit(:name, :team_id, :starts_on, :ends_on, :status)
  end

  def status_rows_for(issue_list)
    counts = issue_list.group_by(&:issue_status_id).transform_values(&:size)
    rows = @cycle.team.issue_statuses.order(:position).filter_map do |status|
      count = counts.delete(status.id)
      [ status.name, status.category, count ] if count.to_i.positive?
    end

    unassigned_count = counts.fetch(nil, 0)
    rows << [ "Backlog", "backlog", unassigned_count ] if unassigned_count.positive?
    rows
  end
end

class IssuesController < AuthenticatedController
  before_action :set_issue, only: %i[show edit update]

  def index
    @view = params[:view].presence || "inbox"
    @issues = current_workspace.issues.includes(:team, :project, :cycle, :issue_status, :assignee).order(updated_at: :desc)
    @issues = @issues.where(assignee: current_user) if @view == "my"
    @issues = @issues.where(cycle: current_team.cycles.where(status: "active")) if @view == "active_cycle" && current_team
  end

  def show
    @runs = @issue.pipeline_runs.order(created_at: :desc)
    @change_requests = @issue.change_requests.order(updated_at: :desc)
  end

  def new
    @issue = current_workspace.issues.new(team: current_team, project_id: params[:project_id])
  end

  def create
    @issue = current_workspace.issues.new(issue_params)
    @issue.team ||= current_team
    if @issue.save
      redirect_to @issue, notice: "Issue created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @issue.update(issue_params)
      redirect_to @issue, notice: "Issue updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_issue
    @issue = current_workspace.issues.find(params[:id])
  end

  def issue_params
    params.require(:issue).permit(:title, :description, :team_id, :project_id, :cycle_id, :issue_status_id, :assignee_id, :parent_id, :priority, :estimate, :due_on)
  end
end

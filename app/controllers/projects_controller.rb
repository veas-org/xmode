class ProjectsController < AuthenticatedController
  before_action :set_project, only: %i[show edit update]

  def index
    @projects = current_workspace.projects.includes(:team).order(updated_at: :desc)
  end

  def show
    @issues = @project.issues.includes(:issue_status, :assignee).order(updated_at: :desc)
    @runs = @project.pipeline_runs.order(created_at: :desc).limit(10)
  end

  def new
    @project = current_workspace.projects.new(team: current_team)
  end

  def create
    @project = current_workspace.projects.new(project_params)
    @project.team ||= current_team
    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = current_workspace.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :description, :status, :team_id, :repository_url)
  end
end

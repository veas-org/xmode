class CyclesController < AuthenticatedController
  before_action :set_cycle, only: %i[show edit update]

  def index
    @cycles = current_workspace.cycles.includes(:team).order(starts_on: :desc, created_at: :desc)
  end

  def show
    @issues = @cycle.issues.includes(:issue_status, :project, :assignee).order(updated_at: :desc)
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
end

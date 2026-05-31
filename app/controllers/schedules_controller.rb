class SchedulesController < AuthenticatedController
  before_action :set_schedule, only: %i[show edit update]

  def index
    @schedules = current_workspace.schedules.includes(:pipeline_definition).order(created_at: :desc)
  end

  def show
  end

  def new
    @schedule = current_workspace.schedules.new(kind: "one_off", pipeline_definition_id: params[:pipeline_definition_id])
  end

  def create
    @schedule = current_workspace.schedules.new(schedule_params)
    if @schedule.save
      redirect_to @schedule, notice: "Schedule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @schedule.update(schedule_params)
      redirect_to @schedule, notice: "Schedule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_schedule
    @schedule = current_workspace.schedules.find(params[:id])
  end

  def schedule_params
    params.require(:schedule).permit(:pipeline_definition_id, :kind, :run_at, :cron, :status)
  end
end

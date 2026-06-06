class SandboxSessionsController < AuthenticatedController
  before_action -> { require_permission!("run_code_actions") }, only: %i[create stop]
  before_action :set_sandbox_session, only: %i[show stop]

  def index
    @sandbox_usage = SandboxSession.open_usage_for(workspace: current_workspace, user: current_user)
    @projects = current_workspace.projects.order(:title)
    @open_sandbox_sessions = current_workspace.sandbox_sessions
      .open
      .includes(:project, :execution_environment, :pipeline_run, :sandbox_commands)
      .recent
    @pending_sandbox_runs = current_workspace.pipeline_runs
      .where(trigger: "sandbox", user: current_user, status: SandboxSession::ACTIVE_RUN_STATUSES)
      .where.not(id: @open_sandbox_sessions.select(:pipeline_run_id))
      .includes(:pipeline_definition, :project)
      .order(created_at: :desc)
    @recent_sandbox_sessions = current_workspace.sandbox_sessions
      .where.not(id: @open_sandbox_sessions.select(:id))
      .includes(:project, :execution_environment, :pipeline_run, :sandbox_commands)
      .recent
      .limit(20)
  end

  def show
    @sandbox_files = Sandboxes::FileInventory.call(@sandbox_session)
    @recent_commands = @sandbox_session.sandbox_commands.includes(:user).order(created_at: :desc)
    @workspace_open_sandboxes = current_workspace.sandbox_sessions
      .open
      .where.not(id: @sandbox_session.id)
      .includes(:project, :execution_environment, :pipeline_run)
      .recent
      .limit(8)
  end

  def create
    project = current_workspace.projects.find(params.require(:project_id))
    result = Sandboxes::Starter.call(
      workspace: current_workspace,
      user: current_user,
      project: project,
      objective: params[:objective]
    )

    if result.success?
      redirect_to pipeline_run_path(result.run), notice: "Sandbox run started."
    elsif result.error == :open_limit_reached
      usage = result.usage
      redirect_to sandbox_sessions_path, alert: "Open sandbox limit reached (#{usage.fetch(:used_count)}/#{usage.fetch(:limit)}). Stop an open sandbox before starting another."
    else
      redirect_to sandbox_sessions_path, alert: "Sandbox pipeline is not available for this project."
    end
  end

  def stop
    if @sandbox_session.open?
      @sandbox_session.stop!(user: current_user)
      redirect_back fallback_location: sandbox_session_path(@sandbox_session), notice: "Sandbox stopped."
    else
      redirect_back fallback_location: sandbox_session_path(@sandbox_session), alert: "Sandbox is already stopped."
    end
  end

  private

  def set_sandbox_session
    @sandbox_session = current_workspace.sandbox_sessions
      .includes(:project, :execution_environment, :pipeline_run)
      .find(params[:id])
  end
end

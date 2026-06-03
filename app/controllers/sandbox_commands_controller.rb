class SandboxCommandsController < AuthenticatedController
  before_action -> { require_permission!("run_code_actions") }
  before_action :set_run
  before_action :set_sandbox_session

  def create
    command_text = params.require(:command).to_s.strip
    if command_text.blank?
      redirect_to pipeline_run_path(@run), alert: "Command cannot be blank."
      return
    end

    command = @sandbox_session.sandbox_commands.create!(
      pipeline_run: @run,
      action_run_step: @sandbox_session.action_run_step,
      user: current_user,
      command: command_text
    )
    Sandboxes::CommandRunner.call(command)
    redirect_to pipeline_run_path(@run), notice: "Sandbox command recorded."
  end

  private

  def set_run
    @run = current_workspace.pipeline_runs.find(params[:pipeline_run_id])
  end

  def set_sandbox_session
    @sandbox_session = @run.sandbox_sessions.find(params[:sandbox_session_id])
  end
end

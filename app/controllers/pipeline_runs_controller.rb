class PipelineRunsController < AuthenticatedController
  before_action :set_run, only: %i[show approve reject resume cancel]

  def index
    @runs = current_workspace.pipeline_runs.includes(:pipeline_definition, :issue, :project).order(created_at: :desc)
  end

  def show
    @steps = @run.action_run_steps.order(:position)
    @logs = @run.run_logs.order(:created_at)
    @artifacts = @run.run_artifacts.order(:created_at)
    @approvals = @run.approvals.order(:created_at)
  end

  def approve
    approval = @run.approvals.where(status: "pending").last
    approval&.update!(status: "approved", decision: "approved", user: current_user, notes: params[:notes])
    approval&.action_run_step&.update!(status: "completed", output_json: { approved: true, summary: "Approved by #{current_user.display_name}" }, finished_at: Time.current)
    @run.update!(status: "queued")
    PipelineRunnerJob.perform_later(@run.id)
    redirect_to pipeline_run_path(@run), notice: "Approved and resumed."
  end

  def reject
    approval = @run.approvals.where(status: "pending").last
    approval&.update!(status: "rejected", decision: "rejected", user: current_user, notes: params[:notes])
    approval&.action_run_step&.update!(status: "failed", error_message: "Rejected", finished_at: Time.current)
    @run.update!(status: "failed", error_message: "Rejected by #{current_user.display_name}", finished_at: Time.current)
    redirect_to pipeline_run_path(@run), notice: "Run rejected."
  end

  def resume
    PipelineRunnerJob.perform_later(@run.id)
    redirect_to pipeline_run_path(@run), notice: "Run resumed."
  end

  def cancel
    @run.update!(status: "canceled", finished_at: Time.current)
    redirect_to pipeline_run_path(@run), notice: "Run canceled."
  end

  private

  def set_run
    @run = current_workspace.pipeline_runs.find(params[:id])
  end
end

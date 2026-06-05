class PipelineRunsController < AuthenticatedController
  before_action :set_run, only: %i[show approve reject resume cancel]

  def index
    @runs = current_workspace.pipeline_runs
      .includes(:pipeline_definition, :issue, :project, :event, :change_request, :approvals, :run_artifacts)
      .order(created_at: :desc)
    @run_counts = {
      waiting: @runs.count { |run| run.status == "waiting_for_approval" },
      active: @runs.count { |run| run.status.in?(%w[queued running waiting_for_input]) },
      completed: @runs.count { |run| run.status == "completed" },
      failed: @runs.count { |run| run.status.in?(%w[failed canceled]) }
    }
  end

  def show
    @session_runs = current_workspace.pipeline_runs
      .includes(:pipeline_definition, :issue, :project)
      .order(created_at: :desc)
      .limit(30)
    @steps = @run.action_run_steps.order(:position)
    @logs = @run.run_logs.order(:created_at)
    @artifacts = @run.run_artifacts.order(:created_at)
    @approvals = @run.approvals.order(:created_at)
    @pending_approval = @approvals.find { |approval| approval.status == "pending" }
    @run_messages = @run.run_messages.includes(:user, :action_run_step).order(:created_at)
    @pending_run_message = @run_messages.find(&:pending?)
    @sandbox_sessions = @run.sandbox_sessions.includes(:action_run_step, :execution_environment, :sandbox_commands).order(:created_at)
    @sandbox_files_by_session_id = @sandbox_sessions.index_with { |sandbox| Sandboxes::FileInventory.call(sandbox) }.transform_keys(&:id)
    @change_request = @run.change_request
    @snapshot_nodes = @run.pipeline_snapshot.dig("graph", "nodes") || []
    @can_resume = @run.status.in?(%w[queued failed])
    @can_cancel = @run.status.in?(%w[queued running waiting_for_approval waiting_for_input])
  end

  def approve
    approval = @run.approvals.where(status: "pending").last
    approval&.update!(status: "approved", decision: "approved", user: current_user, notes: params[:notes])
    approval&.action_run_step&.update!(status: "completed", output_json: { approved: true, summary: "Approved by #{current_user.display_name}" }, finished_at: Time.current)
    @run.update!(status: "queued")
    audit_run!("pipeline_run.approved", metadata: { approval_id: approval&.id, notes_present: params[:notes].present? })
    PipelineRunnerJob.perform_later(@run.id)
    redirect_to pipeline_run_path(@run), notice: "Approved and resumed."
  end

  def reject
    approval = @run.approvals.where(status: "pending").last
    approval&.update!(status: "rejected", decision: "rejected", user: current_user, notes: params[:notes])
    approval&.action_run_step&.update!(status: "failed", error_message: "Rejected", finished_at: Time.current)
    @run.update!(status: "failed", error_message: "Rejected by #{current_user.display_name}", finished_at: Time.current)
    Billing::UsageRecorder.call(@run)
    audit_run!("pipeline_run.rejected", severity: "warn", metadata: { approval_id: approval&.id, notes_present: params[:notes].present? })
    redirect_to pipeline_run_path(@run), notice: "Run rejected."
  end

  def resume
    audit_run!("pipeline_run.resumed")
    PipelineRunnerJob.perform_later(@run.id)
    redirect_to pipeline_run_path(@run), notice: "Run resumed."
  end

  def cancel
    @run.update!(status: "canceled", finished_at: Time.current)
    Billing::UsageRecorder.call(@run)
    audit_run!("pipeline_run.canceled", severity: "warn")
    redirect_to pipeline_run_path(@run), notice: "Run canceled."
  end

  private

  def set_run
    @run = current_workspace.pipeline_runs.find(params[:id])
  end

  def audit_run!(action, severity: "info", metadata: {})
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: @run,
      action: action,
      severity: severity,
      source: "app",
      metadata: {
        pipeline_run_id: @run.id,
        pipeline_definition_id: @run.pipeline_definition_id,
        status: @run.status
      }.merge(metadata),
      request: request
    )
  end
end

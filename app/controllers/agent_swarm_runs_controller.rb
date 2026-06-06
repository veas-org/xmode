class AgentSwarmRunsController < AuthenticatedController
  before_action -> { require_permission!("run_code_actions") }, only: %i[create cancel]
  before_action :set_run, only: %i[show cancel]

  def show
    @automation_run = @run.automation_run
    @member_results = @run.member_results
    @member_snapshots = @run.member_snapshots
    @coordinator = @run.coordinator_snapshot
  end

  def create
    swarm = current_workspace.agent_swarm_definitions.find(params[:agent_swarm_definition_id])
    run = current_workspace.agent_swarm_runs.create!(
      agent_swarm_definition: swarm,
      user: current_user,
      trigger: params[:trigger].presence || "manual",
      objective: params[:objective].presence || "Coordinate #{swarm.name}.",
      project: project,
      issue: issue
    )
    audit_run!(run, "agent_swarm_run.created")
    AgentSwarmRunnerJob.perform_later(run.id)
    redirect_to agent_swarm_run_path(run), notice: "Swarm run started."
  end

  def cancel
    if @run.status.in?(%w[queued running])
      @run.update!(status: "canceled", finished_at: Time.current)
      audit_run!(@run, "agent_swarm_run.canceled", severity: "warn")
      redirect_to agent_swarm_run_path(@run), notice: "Swarm run canceled."
    else
      redirect_to agent_swarm_run_path(@run), alert: "Only queued or running swarm runs can be canceled."
    end
  end

  private

  def set_run
    @run = current_workspace.agent_swarm_runs
      .includes(:agent_swarm_definition, :user, :project, :issue)
      .find(params[:id])
  end

  def project
    return if params[:project_id].blank?

    current_workspace.projects.find(params[:project_id])
  end

  def issue
    return if params[:issue_id].blank?

    current_workspace.issues.find(params[:issue_id])
  end

  def audit_run!(run, action, severity: "info")
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: run,
      action: action,
      severity: severity,
      source: "app",
      metadata: {
        agent_swarm_run_id: run.id,
        agent_swarm_definition_id: run.agent_swarm_definition_id,
        status: run.status
      },
      request: request
    )
  end
end

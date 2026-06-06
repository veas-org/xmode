class PipelineCodexMessagesController < AuthenticatedController
  before_action -> { require_permission!("manage_workspace") }
  before_action :set_run

  def create
    content = params[:content].to_s.strip
    if content.blank?
      redirect_to pipeline_run_path(@run), alert: "Message cannot be blank."
      return
    end

    codex_session = @run.codex_sessions.recent.first || build_codex_session!
    CodexSdk::Session.interact!(codex_session, content: content, user: current_user)
    audit_message!(codex_session)

    redirect_to pipeline_run_path(@run), notice: "Message sent to Codex CLI."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to pipeline_run_path(@run), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_run
    @run = current_workspace.pipeline_runs.find(params[:pipeline_run_id])
  end

  def build_codex_session!
    runtime = CodexSession.default_runtime
    @run.codex_sessions.create!(
      workspace: current_workspace,
      user: current_user,
      project: @run.project,
      title: "Run ##{@run.id} CLI agent",
      objective: session_objective,
      runtime: runtime,
      model: CodexSession.default_model(runtime),
      cloud_environment_id: ENV["CODEX_CLOUD_ENV_ID"].presence,
      branch: ENV["CODEX_CLOUD_BRANCH"].presence,
      working_directory: CodexSession.default_working_directory,
      sandbox_mode: "workspace-write",
      approval_policy: "never",
      metadata: {
        "source" => "pipeline_run",
        "pipeline_run_id" => @run.id,
        "codex_cli" => runtime.in?(%w[local_cli docker_cli]),
        "docker_cli" => runtime == "docker_cli",
        "cloud_cli" => runtime == "cloud_subscription"
      }.compact
    )
  end

  def session_objective
    [
      "Communicate with the CLI agent for pipeline run ##{@run.id}.",
      "Pipeline: #{@run.pipeline_definition&.name || "Pipeline run"}",
      "Status: #{@run.display_status}",
      ("Project: #{@run.project.title}" if @run.project),
      ("Issue: #{@run.issue.identifier} - #{@run.issue.title}" if @run.issue),
      "Run objective: #{run_objective}"
    ].compact.join("\n")
  end

  def run_objective
    context = (@run.input_context || {}).to_h
    context["objective"].presence ||
      @run.action_run_steps.order(:position).map { |step| (step.input_json || {}).to_h["objective"].presence }.compact.first ||
      @run.issue&.title ||
      "Objective not captured."
  end

  def audit_message!(codex_session)
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: codex_session,
      action: "codex_session.message_created",
      source: "app",
      metadata: {
        pipeline_run_id: @run.id,
        codex_session_id: codex_session.id,
        runtime: codex_session.runtime,
        model: codex_session.model
      },
      request: request
    )
  end
end

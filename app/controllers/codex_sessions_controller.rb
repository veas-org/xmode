class CodexSessionsController < AuthenticatedController
  before_action -> { require_permission!("manage_workspace") }
  before_action :set_codex_session, only: %i[show message]

  def index
    @codex_sessions = current_workspace.codex_sessions.includes(:user, :project).recent.limit(25)
    @codex_session = current_workspace.codex_sessions.new(
      runtime: CodexSession.default_runtime,
      model: CodexSession.default_model,
      cloud_environment_id: ENV["CODEX_CLOUD_ENV_ID"].presence,
      working_directory: CodexSession.default_working_directory,
      branch: ENV["CODEX_CLOUD_BRANCH"].presence,
      sandbox_mode: "workspace-write",
      approval_policy: "never"
    )
  end

  def show
    @codex_sessions = current_workspace.codex_sessions.includes(:user, :project).recent.limit(25)
    @messages = @codex_session.codex_session_messages.includes(:user).chronological
  end

  def create
    codex_session = CodexSdk::Session.open!(
      workspace: current_workspace,
      user: current_user,
      objective: codex_session_params.fetch(:objective),
      title: codex_session_params[:title],
      runtime: codex_session_params[:runtime],
      model: codex_session_params[:model],
      cloud_environment_id: codex_session_params[:cloud_environment_id],
      branch: codex_session_params[:branch],
      working_directory: codex_session_params[:working_directory],
      sandbox_mode: codex_session_params[:sandbox_mode],
      approval_policy: codex_session_params[:approval_policy],
      source: "admin_codex_sessions"
    )
    current_workspace.audit_events.create!(
      user: current_user,
      auditable: codex_session,
      action: "codex_session.created",
      source: "app",
      metadata: {
        runtime: codex_session.runtime,
        model: codex_session.model,
        cloud_environment_id: codex_session.cloud_environment_id
      }.compact
    )
    redirect_to codex_session_path(codex_session), notice: "Codex session opened."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to codex_sessions_path, alert: e.record.errors.full_messages.to_sentence
  end

  def message
    content = params.require(:codex_session_message).fetch(:content).to_s.strip
    if content.blank?
      redirect_to codex_session_path(@codex_session), alert: "Message cannot be blank."
      return
    end

    CodexSdk::Session.interact!(@codex_session, content: content, user: current_user)
    redirect_to codex_session_path(@codex_session), notice: "Message sent to Codex."
  end

  private

  def set_codex_session
    @codex_session = current_workspace.codex_sessions.find(params[:id])
  end

  def codex_session_params
    params.require(:codex_session).permit(
      :title,
      :objective,
      :runtime,
      :model,
      :cloud_environment_id,
      :branch,
      :working_directory,
      :sandbox_mode,
      :approval_policy
    )
  end
end

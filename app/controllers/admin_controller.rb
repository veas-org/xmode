class AdminController < AuthenticatedController
  MODEL_NAME_PATTERN = /\A[\w.\/:-]+\z/
  MODEL_NAME_LIMIT = 120

  before_action -> { require_permission!("manage_workspace") }

  def show
    @subscription = current_workspace.billing_subscriptions.order(created_at: :desc).first
    @admin_counts = admin_counts
    @readiness_rows = readiness_rows
    @security_rows = security_rows
    @recent_audit_events = current_workspace.audit_events.includes(:user).order(created_at: :desc).limit(6)
    @recent_failed_runs = current_workspace.pipeline_runs.includes(:pipeline_definition, :issue, :project).where(status: %w[failed canceled]).order(updated_at: :desc).limit(5)
    @open_approvals = Approval.includes(:pipeline_run, :action_run_step).where(pipeline_run: current_workspace.pipeline_runs, status: "pending").order(created_at: :desc).limit(5)
  end

  def qwen
    load_qwen_console
    @qwen_request = selected_qwen_request
    hydrate_qwen_form_from_request if @qwen_request
  end

  def ask_qwen
    load_qwen_console
    @qwen_prompt = params[:prompt].to_s.strip
    @qwen_system_prompt = params[:system_prompt].to_s.strip.presence || default_qwen_system_prompt
    @qwen_model = selected_qwen_model

    if @qwen_prompt.blank?
      @qwen_error = "Prompt cannot be blank."
      return render :qwen, status: :unprocessable_content
    end

    if @qwen_model.blank?
      @qwen_error = "Model name can only include letters, numbers, slash, dot, colon, underscore, and dash."
      return render :qwen, status: :unprocessable_content
    end

    @qwen_request = current_workspace.admin_model_requests.create!(
      user: current_user,
      status: "queued",
      runtime: @qwen_runtime,
      model: @qwen_model,
      base_url: @qwen_base_url,
      timeout_seconds: @qwen_timeout,
      system_prompt: @qwen_system_prompt,
      prompt: @qwen_prompt
    )
    AdminModelRequestJob.perform_later(@qwen_request.id)
    redirect_to qwen_admin_path(model_request_id: @qwen_request.id), status: :see_other
  end

  private

  def load_qwen_console
    @qwen_runtime = ENV.fetch("LOCAL_MODEL_RUNTIME", "ollama")
    @qwen_model = ENV.fetch("LOCAL_MODEL_NAME", "qwen2.5:0.5b")
    @qwen_model_options = qwen_model_options
    @qwen_custom_model = ""
    @qwen_base_url = ENV["LOCAL_MODEL_BASE_URL"].presence || ENV["OLLAMA_BASE_URL"].presence || "http://xmode-ollama:11434"
    @qwen_timeout = ENV.fetch("LOCAL_MODEL_TIMEOUT_SECONDS", 120).to_i
    @qwen_system_prompt = default_qwen_system_prompt
    @qwen_prompt = default_qwen_prompt
  end

  def default_qwen_system_prompt
    "You are xmode's private admin model console. Return one JSON object with keys summary, answer, recommended_next_steps, risk_notes. Keep answers concise and do not claim to run code."
  end

  def default_qwen_prompt
    "Summarize the current xmode local-model setup and suggest the next safe operator check."
  end

  def selected_qwen_model
    @qwen_custom_model = params[:custom_model].to_s.strip
    model = @qwen_custom_model.presence || params[:model].to_s.strip.presence || @qwen_model
    return model if model.length <= MODEL_NAME_LIMIT && model.match?(MODEL_NAME_PATTERN)

    nil
  end

  def qwen_model_options
    default_model = ENV.fetch("LOCAL_MODEL_NAME", "qwen2.5:0.5b")
    [
      [ "Configured default (#{default_model})", default_model ],
      [ "Current tiny Qwen (qwen2.5:0.5b)", "qwen2.5:0.5b" ],
      [ "Qwen3 latest (qwen3:latest)", "qwen3:latest" ],
      [ "Qwen3 8B (qwen3:8b)", "qwen3:8b" ],
      [ "Qwen3.6 latest (qwen3.6:latest)", "qwen3.6:latest" ],
      [ "Qwen3.6 27B (qwen3.6:27b)", "qwen3.6:27b" ],
      [ "Qwen3.6 35B latest (qwen3.6:35b)", "qwen3.6:35b" ],
      [ "MiniMax M3 cloud (minimax-m3:cloud)", "minimax-m3:cloud" ],
      [ "MiniMax M2.7 cloud (minimax-m2.7:cloud)", "minimax-m2.7:cloud" ]
    ].uniq { |_label, value| value }
  end

  def selected_qwen_request
    scope = current_workspace.admin_model_requests.where(user: current_user).order(created_at: :desc)
    return scope.find_by(id: params[:model_request_id]) if params[:model_request_id].present?

    scope.first
  end

  def hydrate_qwen_form_from_request
    @qwen_model = @qwen_request.model
    @qwen_custom_model = @qwen_model unless @qwen_model_options.any? { |_label, value| value == @qwen_model }
    @qwen_prompt = @qwen_request.prompt
    @qwen_system_prompt = @qwen_request.system_prompt
  end

  def admin_counts
    {
      members: current_workspace.memberships.count,
      pending_invites: current_workspace.invitations.select(&:pending?).count,
      projects: current_workspace.projects.count,
      issues: current_workspace.issues.count,
      pipelines: current_workspace.pipeline_definitions.count,
      event_rules: current_workspace.event_rules.where(active: true).count,
      active_runs: current_workspace.pipeline_runs.where(status: %w[queued running waiting_for_approval waiting_for_input]).count,
      failed_runs: current_workspace.pipeline_runs.where(status: %w[failed canceled]).count,
      change_requests: current_workspace.change_requests.count,
      audit_events: current_workspace.audit_events.count
    }
  end

  def readiness_rows
    [
      readiness("Members", @admin_counts.fetch(:members).positive?, "#{@admin_counts.fetch(:members)} workspace members"),
      readiness("Pipelines", @admin_counts.fetch(:pipelines).positive?, "#{@admin_counts.fetch(:pipelines)} reusable definitions"),
      readiness("Event rules", @admin_counts.fetch(:event_rules).positive?, "#{@admin_counts.fetch(:event_rules)} active routing rules"),
      readiness("Repositories", current_workspace.repository_connections.exists?, "#{current_workspace.repository_connections.count} connected repositories"),
      readiness("Change Requests", @admin_counts.fetch(:change_requests).positive?, "#{@admin_counts.fetch(:change_requests)} review records"),
      readiness("Audit trail", @admin_counts.fetch(:audit_events).positive?, "#{@admin_counts.fetch(:audit_events)} events recorded"),
      readiness("Billing", @subscription.present?, @subscription ? "#{@subscription.plan.titleize} / #{@subscription.status.titleize}" : "No subscription record"),
      readiness("Webhook intake", current_workspace.webhook_secret.present?, current_workspace.webhook_secret.present? ? "Signed endpoint ready" : "Missing signing secret")
    ]
  end

  def security_rows
    [
      [ "Admin members", current_workspace.memberships.where(role: %w[owner admin]).count ],
      [ "Pending approvals", Approval.where(pipeline_run: current_workspace.pipeline_runs, status: "pending").count ],
      [ "Failed runs", @admin_counts.fetch(:failed_runs) ],
      [ "Audit errors", current_workspace.audit_events.where(severity: "error").count ],
      [ "Provider integrations", current_workspace.integration_accounts.count ],
      [ "Sandbox sessions", SandboxSession.where(pipeline_run: current_workspace.pipeline_runs).count ]
    ]
  end

  def readiness(label, ready, detail)
    {
      label: label,
      status: ready ? "ready" : "needed",
      detail: detail
    }
  end
end

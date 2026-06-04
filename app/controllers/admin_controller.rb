class AdminController < AuthenticatedController
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
  end

  def ask_qwen
    load_qwen_console
    @qwen_prompt = params[:prompt].to_s.strip
    @qwen_system_prompt = params[:system_prompt].to_s.strip.presence || default_qwen_system_prompt

    if @qwen_prompt.blank?
      @qwen_error = "Prompt cannot be blank."
      return render :qwen, status: :unprocessable_content
    end

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Providers::LocalModelClient.call(
      base_url: @qwen_base_url,
      payload: qwen_payload,
      timeout: @qwen_timeout
    )
    @qwen_duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000).round
    @qwen_raw_response = response
    @qwen_answer = response.dig("message", "content").presence || response["response"].to_s
    @qwen_answer_json = parse_answer_json(@qwen_answer)
    render :qwen
  rescue Providers::LocalModelClient::Error => e
    @qwen_error = e.message
    render :qwen, status: :bad_gateway
  end

  private

  def load_qwen_console
    @qwen_runtime = ENV.fetch("LOCAL_MODEL_RUNTIME", "ollama")
    @qwen_model = ENV.fetch("LOCAL_MODEL_NAME", "qwen2.5:0.5b")
    @qwen_base_url = ENV["LOCAL_MODEL_BASE_URL"].presence || ENV["OLLAMA_BASE_URL"].presence || "http://xmode-ollama:11434"
    @qwen_timeout = ENV.fetch("LOCAL_MODEL_TIMEOUT_SECONDS", 120).to_i
    @qwen_system_prompt = default_qwen_system_prompt
    @qwen_prompt = default_qwen_prompt
  end

  def qwen_payload
    {
      model: @qwen_model,
      stream: false,
      format: "json",
      messages: [
        { role: "system", content: @qwen_system_prompt },
        { role: "user", content: @qwen_prompt }
      ],
      options: {
        temperature: 0.2,
        num_predict: 700,
        num_ctx: 4096
      }
    }
  end

  def default_qwen_system_prompt
    "You are xmode's private admin model console. Return one JSON object with keys summary, answer, recommended_next_steps, risk_notes. Keep answers concise and do not claim to run code."
  end

  def default_qwen_prompt
    "Summarize the current xmode local-model setup and suggest the next safe operator check."
  end

  def parse_answer_json(answer)
    JSON.parse(answer.to_s)
  rescue JSON::ParserError
    nil
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

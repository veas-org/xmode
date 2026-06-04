class SettingsController < AuthenticatedController
  def show
    current_workspace.ensure_webhook_secret!
    @subscription = current_subscription
    @settings_sections = settings_sections
    @workspace_rows = workspace_rows
    @account_rows = account_rows
    load_member_settings
    load_sso_settings
    load_local_model_settings
    load_integration_settings
    load_billing_settings
    load_audit_settings
  end

  private

  def settings_sections
    [
      settings_section(
        id: "workspace",
        label: "Workspace",
        description: "Workspace identity, operational readiness, webhook intake, and governance posture.",
        icon: "settings",
        href: admin_path,
        action_label: "Open admin",
        permission: "manage_workspace",
        detail: "#{current_workspace.projects.count} projects"
      ),
      settings_section(
        id: "members",
        label: "Members",
        description: "Invite teammates and manage workspace roles used by approvals and pipeline operations.",
        icon: "user-circle",
        href: invitations_path,
        action_label: "Manage members",
        permission: "manage_members",
        detail: "#{current_workspace.memberships.count} members"
      ),
      settings_section(
        id: "security",
        label: "Security",
        description: "Workspace sign-in policy, OIDC SSO providers, auto-join rules, and identity links.",
        icon: "shield-check",
        href: "#security",
        action_label: "Manage SSO",
        permission: "manage_workspace",
        detail: "#{current_workspace.sso_providers.active.count} SSO"
      ),
      settings_section(
        id: "integrations",
        label: "Integrations",
        description: "Connect GitHub, GitLab, repositories, and signed event intake endpoints.",
        icon: "plug",
        href: integrations_path,
        action_label: "Manage integrations",
        permission: "manage_integrations",
        detail: "#{current_workspace.integration_accounts.count} accounts"
      ),
      {
        id: "models",
        label: "Models",
        description: "Configure code-model routing, BYOK provider keys, and the default model used by planning and sandbox-adjacent work.",
        icon: "cpu",
        href: "#models",
        action_label: "Model routing",
        accessible: permitted?("manage_integrations"),
        detail: code_model_detail
      },
      settings_section(
        id: "billing",
        label: "Billing",
        description: "Hosted SaaS plan state, Stripe readiness, seats, and automation usage limits.",
        icon: "credit-card",
        href: billing_path,
        action_label: "Open billing",
        permission: "manage_billing",
        detail: billing_detail
      ),
      settings_section(
        id: "audit",
        label: "Audit",
        description: "Workspace evidence for approvals, runs, Change Requests, integrations, and security events.",
        icon: "activity",
        href: audit_events_path,
        action_label: "View audit",
        permission: "view_audit_events",
        detail: "#{current_workspace.audit_events.count} events"
      ),
      {
        id: "appearance",
        label: "Appearance",
        description: "Control the local interface theme without mixing appearance into the app topbar.",
        icon: "sparkles",
        href: "#appearance",
        action_label: "Local setting",
        accessible: true,
        detail: current_user.theme_preference.titleize
      }
    ]
  end

  def settings_section(id:, label:, description:, icon:, href:, action_label:, permission:, detail:)
    {
      id: id,
      label: label,
      description: description,
      icon: icon,
      href: href,
      action_label: action_label,
      permission: permission,
      accessible: permitted?(permission),
      detail: detail
    }
  end

  def workspace_rows
    [
      [ "Workspace", current_workspace.name ],
      [ "Slug", current_workspace.slug ],
      [ "Plan", current_workspace.billing_plan.titleize ],
      [ "Team", current_team&.name || "No team" ],
      [ "Webhook", current_workspace.webhook_secret.present? ? "Signed" : "Missing" ]
    ]
  end

  def account_rows
    [
      [ "User", current_user.display_name ],
      [ "Email", current_user.email ],
      [ "Role", current_membership&.role&.titleize || "Member" ],
      [ "Theme preference", current_user.theme_preference.titleize ]
    ]
  end

  def billing_detail
    return "#{@subscription.plan.titleize} #{@subscription.status.tr("_", " ")}" if @subscription

    "#{current_workspace.billing_plan.titleize} plan"
  end

  def code_model_detail
    default_code_model_profile.model
  end

  def local_model_base_url
    ENV["LOCAL_MODEL_BASE_URL"].presence || ENV["OLLAMA_BASE_URL"].presence || "http://xmode-ollama:11434"
  end

  def current_subscription
    current_workspace.billing_subscriptions.order(created_at: :desc).first ||
      current_workspace.billing_subscriptions.create!(
        plan: current_workspace.billing_plan,
        status: "inactive",
        seats: current_workspace.memberships.count
      )
  end

  def load_member_settings
    @memberships = current_workspace.memberships.includes(:user, :team).to_a.sort_by { |membership| [ membership.role, membership.user.display_name ] }
    @invitations = current_workspace.invitations.includes(:team).order(created_at: :desc)
    @member_counts = {
      total: @memberships.size,
      owners: @memberships.count { |membership| membership.role == "owner" },
      admins: @memberships.count { |membership| membership.role == "admin" },
      pending_invites: @invitations.count { |invitation| !invitation.accepted? && !invitation.expired? }
    }
  end

  def load_sso_settings
    @sso_providers = current_workspace.sso_providers.order(:name)
    @sso_identity_count = SsoIdentity.joins(:sso_provider).where(sso_providers: { workspace_id: current_workspace.id }).count
    @sso_counts = {
      providers: @sso_providers.size,
      active: @sso_providers.count(&:active?),
      identities: @sso_identity_count,
      auto_join: @sso_providers.count(&:allow_signups?)
    }
  end

  def load_local_model_settings
    @default_code_model_profile = default_code_model_profile
    @code_model_profiles = current_workspace.code_model_profiles.order(default_profile: :desc, provider: :asc, name: :asc)
    @new_code_model_profile = current_workspace.code_model_profiles.new(
      provider: "openai",
      name: "OpenAI BYOK",
      model: CodeModelProfile::DEFAULT_MODELS.fetch("openai"),
      base_url: CodeModelProfile::DEFAULT_BASE_URLS.fetch("openai"),
      timeout_seconds: 3600,
      temperature: 0.2,
      max_tokens: 1024,
      context_window: 8192,
      status: "active"
    )
    @code_model_provider_options = CodeModelProfile.provider_options
    @code_model_status_options = CodeModelProfile::STATUSES.map { |status| [ status.titleize, status ] }
    @local_model_base_url = @default_code_model_profile.base_url
    @local_model_name = @default_code_model_profile.model
    @local_model_runtime = @default_code_model_profile.provider
    @local_model_timeout = @default_code_model_profile.timeout_seconds
    @local_model_enabled = ActiveModel::Type::Boolean.new.cast(ENV["LOCAL_MODEL_ENABLED"])
    @local_model_rows = [
      [ "Default profile", @default_code_model_profile.name ],
      [ "Provider", @default_code_model_profile.display_provider ],
      [ "Model", @local_model_name ],
      [ "Endpoint", @local_model_base_url ],
      [ "Credential mode", @default_code_model_profile.credential_label ],
      [ "Default mode", @local_model_enabled ? "Live for code-model actions" : "Action opt-in" ],
      [ "Timeout", "#{@local_model_timeout} seconds" ]
    ]
  end

  def default_code_model_profile
    @default_code_model_profile ||= CodeModelProfile.ensure_default_for(current_workspace)
  end

  def load_integration_settings
    @integrations = current_workspace.integration_accounts.order(:provider, :name)
    @repositories = current_workspace.repository_connections.order(:provider, :full_name)
    @github_app_accounts = @integrations.select(&:github_app?)
    @github_app_install_account = @github_app_accounts.find { |integration| integration.github_app_slug.present? && integration.github_installation_id.blank? }
    @github_app_env_installable = Integrations::GithubAppCredentials.installable?
    @webhook_endpoint = "#{request.base_url}/webhooks/events/#{current_workspace.slug}/generic"
    @integration_counts = {
      accounts: @integrations.size,
      repositories: @repositories.size,
      active: @integrations.count { |integration| integration.status == "active" },
      providers: (@integrations.map(&:provider) + @repositories.map(&:provider)).compact.uniq.size
    }
  end

  def load_billing_settings
    @seat_count = current_workspace.memberships.count
    @billing_admin_count = current_workspace.memberships.where(role: %w[owner admin]).count
    @run_count = current_workspace.pipeline_runs.count
    @active_run_count = current_workspace.pipeline_runs.where(status: %w[queued running waiting_for_approval]).count
    @change_request_count = current_workspace.change_requests.count
    @repository_count = current_workspace.repository_connections.count
    @plan_rows = plan_rows
    @usage_limit = automation_minutes_limit_for(@subscription.plan)
    @usage_percent = usage_percent
    @readiness_rows = readiness_rows
  end

  def load_audit_settings
    @audit_events = current_workspace.audit_events
      .includes(:user, :auditable)
      .order(created_at: :desc)
      .limit(12)
    @event_counts = {
      total: current_workspace.audit_events.count,
      errors: current_workspace.audit_events.where(severity: "error").count,
      warnings: current_workspace.audit_events.where(severity: "warn").count
    }
  end

  def plan_rows
    [
      [ "Community", "Self-hosted AGPL core for project management, skills, actions, pipelines, and Change Requests.", "Open source" ],
      [ "Team", "Hosted collaboration, managed runners, usage metering, billing, and supportable demo workspaces.", "Hosted SaaS" ],
      [ "Enterprise", "Custom retention, private deployment support, audit requirements, SSO-ready account controls, and procurement.", "Commercial" ]
    ]
  end

  def readiness_rows
    [
      [ "Stripe customer", current_workspace.stripe_customer_id.present? ? "Connected" : "Not connected" ],
      [ "Subscription record", @subscription.stripe_subscription_id.present? ? "Synced" : "Local scaffold" ],
      [ "Billing admins", count_label(@billing_admin_count, "member") ],
      [ "Repositories", count_label(@repository_count, "connection") ],
      [ "Automation ledger", count_label(@run_count, "run") ],
      [ "Change Requests", count_label(@change_request_count, "record") ]
    ]
  end

  def automation_minutes_limit_for(plan)
    case plan
    when "team" then 1_000
    when "enterprise" then nil
    else 120
    end
  end

  def usage_percent
    return 0 if @usage_limit.blank?

    [ (@subscription.automation_minutes_used.to_f / @usage_limit * 100).round, 100 ].min
  end

  def count_label(count, noun)
    "#{count} #{noun.pluralize(count)}"
  end
end

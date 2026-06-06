class IntegrationsController < AuthenticatedController
  before_action -> { require_permission!("manage_integrations") }, except: :index
  before_action :set_integration, only: :sync_repositories

  def index
    current_workspace.ensure_webhook_secret!
    @integrations = current_workspace.integration_accounts.order(:provider, :name)
    @repositories = current_workspace.repository_connections.order(:provider, :full_name)
    @webhook_endpoint = "#{request.base_url}/webhooks/events/#{current_workspace.slug}/generic"
    @integration_counts = {
      accounts: @integrations.size,
      repositories: @repositories.size,
      active: @integrations.count { |integration| integration.status == "active" },
      providers: (@integrations.map(&:provider) + @repositories.map(&:provider)).compact.uniq.size
    }
  end

  def new
    @integration = current_workspace.integration_accounts.new(provider: "github")
  end

  def create
    @integration = current_workspace.integration_accounts.new(integration_params)
    if @integration.save
      audit!("integration.created", @integration, metadata: {
        provider: @integration.provider,
        name: @integration.name
      })
      if repository_sync_supported?(@integration) && @integration.token_ciphertext.present?
        connections = sync_repository_connections!(@integration)
        redirect_to integrations_path, notice: "Integration saved. #{connections.size} #{provider_label(@integration)} repositories imported."
      else
        redirect_to integrations_path, notice: "Integration saved."
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue => e
    redirect_to integrations_path, alert: "Integration saved, but #{provider_label(@integration)} repository import failed: #{e.message}"
  end

  def github_app
    start_github_app_install!(account: github_app_account_for_install)
  rescue Integrations::GithubAppCredentials::MissingConfiguration => e
    redirect_to integrations_path, alert: e.message
  end

  def github_app_manifest
    owner = github_owner_param
    unless valid_github_owner?(owner)
      redirect_to settings_path(section: "integrations"), alert: "GitHub organization can contain only letters, numbers, and hyphens."
      return
    end

    @github_app_manifest_state = SecureRandom.hex(24)
    session[:github_app_manifest_state] = @github_app_manifest_state
    @github_app_manifest_action = github_app_manifest_action(owner, @github_app_manifest_state)
    @github_app_manifest_json = Integrations::GithubAppManifest.call(
      workspace: current_workspace,
      base_url: request.base_url,
      redirect_url: github_app_manifest_callback_integrations_url,
      setup_url: github_app_callback_integrations_url
    ).to_json
  end

  def github_app_manifest_callback
    unless valid_github_app_manifest_state?
      redirect_to settings_path(section: "integrations"), alert: "GitHub App creation could not be verified. Please try again."
      return
    end

    app = Integrations::GithubAppManifestConversion.call(params[:code])
    integration = github_app_manifest_integration(app)
    audit!("integration.github_app_created", integration, metadata: {
      provider: "github",
      app_id: app["id"].to_s,
      slug: app["slug"],
      owner: app.dig("owner", "login")
    })

    start_github_app_install!(account: integration)
  rescue => e
    redirect_to settings_path(section: "integrations"), alert: "GitHub App creation failed: #{e.message}"
  end

  def github_app_callback
    return redirect_to integrations_path, alert: "GitHub App installation could not be verified. Please try again." unless valid_github_app_state?

    installation_id = params[:installation_id].to_s.presence
    return redirect_to integrations_path, alert: "GitHub did not return an installation id." if installation_id.blank?

    @integration = github_app_context_account || github_app_integration(installation_id)
    @integration.assign_attributes(
      provider: "github",
      name: @integration.name.presence || "GitHub App #{installation_id}",
      status: "active",
      metadata: @integration.metadata.to_h.merge(
        "auth_type" => "github_app",
        "installation_id" => installation_id,
        "setup_action" => params[:setup_action].to_s.presence,
        "connected_at" => Time.current.iso8601
      ).compact
    )
    @integration.save!
    audit!("integration.github_app_connected", @integration, metadata: {
      provider: "github",
      installation_id: installation_id,
      setup_action: params[:setup_action]
    })

    connections = sync_repository_connections!(@integration)
    redirect_to integrations_path, notice: "GitHub App connected. #{connections.size} repositories imported."
  rescue => e
    @integration&.update!(
      status: "errored",
      metadata: @integration.metadata.to_h.merge(
        "last_repository_sync_at" => Time.current.iso8601,
        "last_repository_sync_error" => e.message
      )
    )
    redirect_to integrations_path, alert: "GitHub App connected, but repository import failed: #{e.message}"
  end

  def sync_repositories
    connections = sync_repository_connections!(@integration)
    redirect_to integrations_path, notice: "#{connections.size} #{provider_label(@integration)} repositories synced."
  rescue => e
    audit!("integration.repositories_sync_failed", @integration, severity: "error", metadata: {
      provider: @integration.provider,
      name: @integration.name,
      error: e.message
    })
    redirect_to integrations_path, alert: "#{provider_label(@integration)} repository sync failed: #{e.message}"
  end

  private

  def set_integration
    @integration = current_workspace.integration_accounts.find(params[:id])
  end

  def integration_params
    params.require(:integration_account).permit(:provider, :name, :token_ciphertext)
  end

  def github_app_integration(installation_id)
    current_workspace.integration_accounts.where(provider: "github").detect do |integration|
      integration.github_app? && integration.github_installation_id == installation_id
    end || current_workspace.integration_accounts.new(provider: "github")
  end

  def github_app_account_for_install
    return if params[:account_id].blank?

    current_workspace.integration_accounts.find(params[:account_id]).tap do |account|
      raise Integrations::GithubAppCredentials::MissingConfiguration, "Selected integration is not a GitHub App." unless account.github_app?
      raise Integrations::GithubAppCredentials::MissingConfiguration, "Selected GitHub App is missing a slug." if account.github_app_slug.blank?
    end
  end

  def start_github_app_install!(account: nil)
    state = SecureRandom.hex(24)
    session[:github_app_state] = state
    session[:github_app_account_id] = account&.id
    redirect_to github_app_install_url(account, state), allow_other_host: true
  end

  def github_app_install_url(account, state)
    if account&.github_app_slug.present?
      Integrations::GithubAppCredentials.install_url(state: state, slug: account.github_app_slug)
    else
      Integrations::GithubAppCredentials.install_url(state: state)
    end
  end

  def github_app_manifest_integration(app)
    current_workspace.integration_accounts.find_or_initialize_by(
      provider: "github",
      name: app["name"].presence || "GitHub App #{app.fetch("id")}"
    ).tap do |integration|
      integration.status = "active"
      integration.token_ciphertext = app.fetch("pem")
      integration.metadata = integration.metadata.to_h.merge(
        "auth_type" => "github_app",
        "credential_source" => "manifest",
        "app_id" => app["id"].to_s,
        "slug" => app["slug"],
        "html_url" => app["html_url"],
        "owner_login" => app.dig("owner", "login"),
        "client_id" => app["client_id"],
        "created_from_manifest_at" => Time.current.iso8601
      ).compact
      integration.save!
    end
  end

  def github_app_context_account
    account_id = session.delete(:github_app_account_id)
    return if account_id.blank?

    current_workspace.integration_accounts.find_by(id: account_id)
  end

  def valid_github_app_state?
    expected_state = session.delete(:github_app_state).to_s
    returned_state = params[:state].to_s
    expected_state.present? &&
      returned_state.present? &&
      expected_state.bytesize == returned_state.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected_state, returned_state)
  end

  def valid_github_app_manifest_state?
    expected_state = session.delete(:github_app_manifest_state).to_s
    returned_state = params[:state].to_s
    expected_state.present? &&
      returned_state.present? &&
      expected_state.bytesize == returned_state.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected_state, returned_state)
  end

  def github_owner_param
    params[:github_owner].to_s.strip.presence
  end

  def valid_github_owner?(owner)
    owner.blank? || owner.match?(/\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z/)
  end

  def github_app_manifest_action(owner, state)
    base = owner.present? ? "https://github.com/organizations/#{owner}/settings/apps/new" : "https://github.com/settings/apps/new"
    uri = URI(base)
    uri.query = { state: state }.to_query
    uri.to_s
  end

  def repository_sync_supported?(integration)
    integration.provider.in?(%w[github gitlab])
  end

  def sync_repository_connections!(integration)
    connections = Integrations::RepositorySync.call(integration)
    audit!("integration.repositories_synced", integration, metadata: {
      provider: integration.provider,
      name: integration.name,
      repositories: connections.size
    })
    connections
  end

  def provider_label(integration)
    {
      "github" => "GitHub",
      "gitlab" => "GitLab"
    }.fetch(integration.provider, integration.provider.titleize)
  end

  def audit!(action, auditable, severity: "info", metadata: {})
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: auditable,
      action: action,
      severity: severity,
      source: "app",
      metadata: metadata,
      request: request
    )
  end
end

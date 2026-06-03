class SsoProvidersController < AuthenticatedController
  before_action -> { require_permission!("manage_workspace") }
  before_action :set_sso_provider, only: %i[edit update]

  def new
    @sso_provider = current_workspace.sso_providers.new(
      provider_type: "oidc",
      status: "active",
      scopes: "openid email profile",
      allow_signups: true,
      default_membership_role: "member"
    )
  end

  def create
    @sso_provider = current_workspace.sso_providers.new(sso_provider_params)
    if @sso_provider.save
      audit!("sso_provider.created")
      redirect_to settings_path(anchor: "security"), notice: "SSO provider saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sso_provider.update(sso_provider_params)
      audit!("sso_provider.updated")
      redirect_to settings_path(anchor: "security"), notice: "SSO provider updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_sso_provider
    @sso_provider = current_workspace.sso_providers.find(params[:id])
  end

  def sso_provider_params
    permitted = params.require(:sso_provider).permit(
      :name,
      :provider_type,
      :status,
      :issuer,
      :authorization_endpoint,
      :token_endpoint,
      :userinfo_endpoint,
      :client_id,
      :client_secret_ciphertext,
      :scopes,
      :email_domain,
      :allow_signups,
      :default_membership_role
    )
    permitted.delete(:client_secret_ciphertext) if @sso_provider&.persisted? && permitted[:client_secret_ciphertext].blank?
    permitted
  end

  def audit!(action)
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: @sso_provider,
      action: action,
      source: "app",
      metadata: {
        name: @sso_provider.name,
        provider_type: @sso_provider.provider_type,
        status: @sso_provider.status
      },
      request: request
    )
  end
end

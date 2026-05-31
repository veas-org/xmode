class IntegrationsController < AuthenticatedController
  before_action -> { require_permission!("manage_integrations") }, except: :index

  def index
    @integrations = current_workspace.integration_accounts.order(:provider, :name)
    @repositories = current_workspace.repository_connections.order(:provider, :full_name)
  end

  def new
    @integration = current_workspace.integration_accounts.new(provider: "github")
  end

  def create
    @integration = current_workspace.integration_accounts.new(integration_params)
    if @integration.save
      redirect_to integrations_path, notice: "Integration saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def integration_params
    params.require(:integration_account).permit(:provider, :name, :token_ciphertext)
  end
end

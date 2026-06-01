class RepositoryConnectionsController < AuthenticatedController
  before_action -> { require_permission!("manage_integrations") }
  before_action :set_repository_connection, only: %i[edit update]
  before_action :set_integration_accounts, only: %i[new edit create update]

  def new
    @repository_connection = current_workspace.repository_connections.new(
      provider: params[:provider].presence || "github",
      integration_account_id: params[:integration_account_id],
      default_branch: "main"
    )
  end

  def create
    @repository_connection = current_workspace.repository_connections.new(repository_connection_params)

    if @repository_connection.save
      redirect_to integrations_path, notice: "Repository connected."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @repository_connection.update(repository_connection_params)
      redirect_to integrations_path, notice: "Repository updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_repository_connection
    @repository_connection = current_workspace.repository_connections.find(params[:id])
  end

  def set_integration_accounts
    @integration_accounts = current_workspace.integration_accounts.order(:provider, :name)
  end

  def repository_connection_params
    params.require(:repository_connection).permit(:integration_account_id, :provider, :name, :full_name, :url, :default_branch)
  end
end

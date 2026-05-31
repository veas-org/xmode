class WorkspacesController < AuthenticatedController
  skip_before_action :ensure_workspace!, only: %i[new create]

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspace.new(workspace_params)
    if @workspace.save
      team = @workspace.teams.create!(name: "Engineering", key: "eng")
      @workspace.memberships.create!(user: current_user, team: team, role: "owner")
      WorkspaceDefaults.seed!(@workspace)
      switch_workspace!(@workspace)
      redirect_to app_path, notice: "Workspace created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def switch
    workspace = current_user.workspaces.find(params[:id])
    switch_workspace!(workspace)
    redirect_to app_path, notice: "Switched workspace."
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name)
  end
end

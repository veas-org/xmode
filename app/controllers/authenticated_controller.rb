class AuthenticatedController < ApplicationController
  before_action :require_login!
  before_action :ensure_workspace!

  layout "app"

  private

  def ensure_workspace!
    return if current_workspace

    redirect_to new_workspace_path, alert: "Create a workspace to continue."
  end
end

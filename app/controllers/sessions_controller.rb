class SessionsController < ApplicationController
  DEMO_WORKSPACES = {
    "planet-express" => {
      name: "Planet Express",
      email: Demo::PlanetExpressSeeder::BENDER_EMAIL
    }
  }.freeze

  def new
    redirect_to app_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password])
      user.update!(last_sign_in_at: Time.current)
      session[:user_id] = user.id
      if session[:invitation_token].present?
        accept_pending_invitation(user)
        return
      end
      redirect_to session.delete(:return_to).presence || app_path, notice: "Signed in."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def demo
    workspace_key = params[:workspace].to_s
    demo_config = DEMO_WORKSPACES[workspace_key]
    unless demo_config
      redirect_to login_path, alert: "Demo workspace not found."
      return
    end

    Demo::PlanetExpressSeeder.call
    user = User.find_by(email: demo_config.fetch(:email))
    workspace = Workspace.find_by(slug: workspace_key)
    unless user && workspace
      redirect_to login_path, alert: "The #{demo_config.fetch(:name)} demo is not available."
      return
    end

    user.update!(last_sign_in_at: Time.current)
    reset_session
    session[:user_id] = user.id
    switch_workspace!(workspace)
    redirect_to app_path, notice: "Opened the #{demo_config.fetch(:name)} demo."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end

  private

  def accept_pending_invitation(user)
    token = session.delete(:invitation_token).presence
    return unless token

    result = Invitations::Accepter.call(user, token)
    if result.success?
      switch_workspace!(result.workspace)
      switch_team!(result.team) if result.team
      redirect_to app_path, notice: "Joined #{result.workspace.name}."
    else
      redirect_to app_path, alert: result.error
    end
  end
end

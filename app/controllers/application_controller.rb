class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user,
    :logged_in?,
    :current_workspace,
    :current_team,
    :current_membership,
    :permitted?,
    :landing_base_url,
    :landing_url,
    :app_base_url,
    :app_url

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login!
    return if logged_in?

    session[:return_to] = request.fullpath
    redirect_to login_path, alert: "Sign in to continue."
  end

  def current_workspace
    return unless current_user

    @current_workspace ||= if session[:workspace_id].present?
      current_user.workspaces.find_by(id: session[:workspace_id])
    end || current_user.workspaces.order(:created_at).first
  end

  def current_team
    return unless current_workspace

    @current_team ||= if session[:team_id].present?
      current_workspace.teams.find_by(id: session[:team_id])
    end || current_workspace.teams.order(:created_at).first
  end

  def current_membership
    return unless current_workspace && current_user

    @current_membership ||= current_workspace.memberships.find_by(user: current_user, team: current_team) ||
      current_workspace.memberships.find_by(user: current_user, team: nil)
  end

  def permitted?(permission)
    current_membership&.permits?(permission)
  end

  def require_permission!(permission)
    return if permitted?(permission)

    redirect_to app_path, alert: "You do not have permission to #{permission.to_s.humanize.downcase}."
  end

  def landing_base_url
    ENV["LANDING_BASE_URL"].to_s.strip.presence
  end

  def landing_url(path = "/")
    external_url(landing_base_url, path)
  end

  def app_base_url
    ENV["APP_BASE_URL"].to_s.strip.presence || request.base_url
  end

  def app_url(path = "/")
    external_url(app_base_url, path)
  end

  def switch_workspace!(workspace)
    session[:workspace_id] = workspace.id
    session.delete(:team_id)
    @current_workspace = workspace
    @current_team = nil
    @current_membership = nil
  end

  def switch_team!(team)
    session[:team_id] = team.id
    @current_team = team
    @current_membership = nil
  end

  def external_url(base_url, path)
    return if base_url.blank?

    normalized_base = base_url.delete_suffix("/")
    normalized_path = path.to_s.presence || "/"
    return normalized_base if normalized_path == "/"

    "#{normalized_base}/#{normalized_path.delete_prefix("/")}"
  end
end

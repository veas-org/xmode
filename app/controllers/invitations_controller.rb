class InvitationsController < AuthenticatedController
  layout :invitation_layout

  skip_before_action :require_login!, only: :show
  skip_before_action :ensure_workspace!, only: %i[show accept]
  before_action -> { require_permission!("manage_members") }, only: %i[index new create]
  before_action :set_invitation_by_token, only: %i[show accept]

  def index
    @memberships = current_workspace.memberships.includes(:user, :team).to_a.sort_by { |membership| [ membership.role, membership.user.display_name ] }
    @invitations = current_workspace.invitations.includes(:team).order(created_at: :desc)
    @member_counts = {
      total: @memberships.size,
      owners: @memberships.count { |membership| membership.role == "owner" },
      admins: @memberships.count { |membership| membership.role == "admin" },
      pending_invites: @invitations.count { |invitation| !invitation.accepted? && !invitation.expired? }
    }
  end

  def new
    @invitation = current_workspace.invitations.new(role: "member", team: current_team)
    @teams = current_workspace.teams.order(:name)
  end

  def create
    @invitation = current_workspace.invitations.new(email: invitation_email, role: invitation_role)
    @invitation.team = current_workspace.teams.find_by(id: params.dig(:invitation, :team_id))

    if @invitation.save
      Audit::Recorder.call(
        workspace: current_workspace,
        user: current_user,
        auditable: @invitation,
        action: "invitation.created",
        source: "app",
        metadata: { email: @invitation.email, role: @invitation.role, team: @invitation.team&.name }.compact,
        request: request
      )
      redirect_to invitations_path, notice: "Invitation created."
    else
      @teams = current_workspace.teams.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    session[:invitation_token] = @invitation.token unless logged_in?
  end

  def accept
    unless logged_in?
      session[:invitation_token] = @invitation.token
      redirect_to login_path, alert: "Sign in to accept the invitation."
      return
    end

    result = Invitations::Accepter.call(current_user, @invitation.token)
    if result.success?
      switch_workspace!(result.workspace)
      switch_team!(result.team) if result.team
      session.delete(:invitation_token)
      redirect_to app_path, notice: "Joined #{result.workspace.name}."
    else
      redirect_to invitation_path(@invitation.token), alert: result.error
    end
  end

  private

  def set_invitation_by_token
    @invitation = Invitation.includes(:workspace, :team).find_by!(token: params[:token])
  end

  def invitation_email
    params.dig(:invitation, :email).to_s
  end

  def invitation_role
    role = params.dig(:invitation, :role).to_s
    role.in?(Membership::ROLES - [ "owner" ]) ? role : "member"
  end

  def invitation_layout
    action_name == "show" ? "application" : "app"
  end
end

require "rails_helper"

RSpec.describe "Invitations", type: :request do
  it "lets workspace admins create invitation links" do
    owner, workspace, team = create_workspace_owner("owner-invites@example.com")

    post login_path, params: { email: owner.email, password: "password123" }
    get invitations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Members")

    get new_invitation_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("app-side-panel")
    expect(response.body).to include("Invite member")

    post invitations_path, params: {
      invitation: {
        email: "amy@example.com",
        role: "member",
        team_id: team.id
      }
    }

    invitation = workspace.invitations.last
    expect(response).to redirect_to(invitations_path)
    expect(invitation).to have_attributes(email: "amy@example.com", role: "member", team: team)
    expect(workspace.audit_events.last).to have_attributes(action: "invitation.created", auditable: invitation, user: owner)
  end

  it "lets a new invited user join without creating a separate workspace" do
    _owner, workspace, team = create_workspace_owner("owner-invited-signup@example.com")
    invitation = workspace.invitations.create!(email: "zoidberg@example.com", role: "member", team: team)

    get invitation_path(invitation.token)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Join #{workspace.name}")

    post signup_path, params: {
      invitation_token: invitation.token,
      user: {
        name: "Zoidberg",
        email: "zoidberg@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    user = User.find_by!(email: "zoidberg@example.com")
    expect(response).to redirect_to(app_path)
    expect(Workspace.count).to eq(1)
    expect(invitation.reload).to be_accepted
    expect(workspace.memberships.find_by!(user: user, team: team)).to have_attributes(role: "member")
    expect(workspace.audit_events.pluck(:action)).to include("invitation.accepted")
  end

  it "accepts a pending invitation after login" do
    _owner, workspace, team = create_workspace_owner("owner-invited-login@example.com")
    invitation = workspace.invitations.create!(email: "leela@example.com", role: "admin", team: team)
    user = User.create!(name: "Leela", email: "leela@example.com", password: "password123")

    get invitation_path(invitation.token)
    post login_path, params: { email: user.email, password: "password123" }

    expect(response).to redirect_to(app_path)
    expect(invitation.reload).to be_accepted
    expect(workspace.memberships.find_by!(user: user, team: team)).to have_attributes(role: "admin")
  end

  it "blocks members from managing invitations" do
    member, _workspace, = create_workspace_owner("member-invites@example.com", role: "member")

    post login_path, params: { email: member.email, password: "password123" }
    get invitations_path

    expect(response).to redirect_to(app_path)
  end

  def create_workspace_owner(email, role: "owner")
    user = User.create!(name: email.split("@").first.titleize, email: email, password: "password123")
    workspace = Workspace.create!(name: "Spec")
    team = workspace.teams.create!(name: "Engineering", key: "eng")
    workspace.memberships.create!(user: user, team: team, role: role)
    [ user, workspace, team ]
  end
end

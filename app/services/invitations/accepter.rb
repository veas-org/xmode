module Invitations
  class Accepter < ApplicationService
    def self.call(user, token)
      new(user, token).call
    end

    def initialize(user, token)
      @user = user
      @token = token
    end

    def call
      invitation = Invitation.includes(:workspace, :team).find_by(token: @token)
      return self.class.failure("Invitation not found.") unless invitation
      return self.class.failure("Invitation has expired.") if invitation.expired?
      return self.class.failure("Invitation has already been accepted.") if invitation.accepted?
      return self.class.failure("Invitation was sent to #{invitation.email}.") unless @user.email.to_s.casecmp?(invitation.email)

      membership = nil
      ApplicationRecord.transaction do
        membership = invitation.workspace.memberships.find_or_initialize_by(user: @user, team: invitation.team)
        membership.role = invitation.role if membership.new_record?
        membership.save!
        invitation.update!(accepted_at: Time.current)
        Audit::Recorder.call(
          workspace: invitation.workspace,
          user: @user,
          auditable: invitation,
          action: "invitation.accepted",
          source: "app",
          metadata: {
            email: invitation.email,
            role: invitation.role,
            team: invitation.team&.name
          }.compact
        )
      end

      self.class.success(invitation: invitation, workspace: invitation.workspace, team: invitation.team, membership: membership)
    end
  end
end

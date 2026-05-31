module Onboarding
  class Signup < ApplicationService
    def self.call(user_params, workspace_name:)
      new(user_params, workspace_name: workspace_name).call
    end

    def initialize(user_params, workspace_name:)
      @user_params = user_params
      @workspace_name = workspace_name.presence || "xmode Workspace"
    end

    def call
      user = User.new(@user_params)
      workspace = nil

      ApplicationRecord.transaction do
        user.save!
        workspace = Workspace.create!(name: @workspace_name)
        team = workspace.teams.create!(name: "Engineering", key: "eng")
        workspace.memberships.create!(user: user, team: team, role: "owner")
        WorkspaceDefaults.seed!(workspace)
      end

      self.class.success(user: user, workspace: workspace)
    rescue ActiveRecord::RecordInvalid => e
      self.class.failure(e.record.errors.full_messages.to_sentence, user: user || User.new(@user_params))
    end
  end
end

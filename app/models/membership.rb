class Membership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze

  ROLE_PERMISSIONS = {
    "owner" => %w[view_project edit_issues manage_pipelines run_code_actions approve_change_requests manage_integrations manage_members manage_billing manage_workspace view_audit_events],
    "admin" => %w[view_project edit_issues manage_pipelines run_code_actions approve_change_requests manage_integrations manage_members manage_billing manage_workspace view_audit_events],
    "member" => %w[view_project edit_issues run_code_actions],
    "viewer" => %w[view_project]
  }.freeze

  belongs_to :workspace
  belongs_to :team, optional: true
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: [ :workspace_id, :team_id ] }

  def permits?(permission)
    ROLE_PERMISSIONS.fetch(role, []).include?(permission.to_s)
  end
end

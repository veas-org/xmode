admin = User.find_or_create_by!(email: ENV.fetch("ADMIN_EMAIL", "admin@xmode.local")) do |user|
  user.name = "xmode Admin"
  user.password = ENV.fetch("ADMIN_PASSWORD", "password123")
  user.password_confirmation = ENV.fetch("ADMIN_PASSWORD", "password123")
end

workspace = Workspace.find_or_create_by!(slug: "xmode") do |record|
  record.name = "xmode"
  record.billing_plan = "community"
end

team = workspace.teams.find_or_create_by!(key: "eng") do |record|
  record.name = "Engineering"
end

workspace.memberships.find_or_create_by!(user: admin, team: team) do |membership|
  membership.role = "owner"
end

WorkspaceDefaults.seed!(workspace)

project = workspace.projects.find_or_create_by!(key: "automation-platform") do |record|
  record.team = team
  record.title = "Automation Platform"
  record.description = "Build the AI-native project management and automation core."
  record.status = "active"
end

workspace.cycles.find_or_create_by!(team: team, name: "Sprint 1") do |cycle|
  cycle.starts_on = Date.current.beginning_of_week
  cycle.ends_on = Date.current.beginning_of_week + 13.days
  cycle.status = "active"
end

workspace.issues.find_or_create_by!(identifier: "ENG-1") do |issue|
  issue.team = team
  issue.project = project
  issue.title = "Implement issue-to-Change-Request automation loop"
  issue.description = "Prove the full xmode loop from issue through plan, approval, runner, tests, review, and Change Request."
  issue.priority = "high"
end

load Rails.root.join("db/seeds/demo_planet_express.rb")

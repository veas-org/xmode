class WorkspaceDefaults
  ISSUE_STATUSES = [
    [ "Backlog", "backlog" ],
    [ "Todo", "unstarted" ],
    [ "In Progress", "started" ],
    [ "Done", "completed" ],
    [ "Canceled", "canceled" ]
  ].freeze

  LABELS = [
    [ "bug", "#ef4444" ],
    [ "feature", "#22c55e" ],
    [ "automation", "#38bdf8" ],
    [ "maintenance", "#f59e0b" ]
  ].freeze

  SAVED_VIEWS = [
    [ "Inbox", "inbox", "inbox" ],
    [ "My Issues", "my-issues", "my_issues" ],
    [ "Team Backlog", "team-backlog", "backlog" ],
    [ "Active Cycle", "active-cycle", "active_cycle" ],
    [ "Project Roadmap", "project-roadmap", "roadmap" ],
    [ "Automation Queue", "automation-queue", "automation_queue" ]
  ].freeze

  def self.seed!(workspace)
    new(workspace).seed!
  end

  def initialize(workspace)
    @workspace = workspace
  end

  def seed!
    team = @workspace.teams.first || @workspace.teams.create!(name: "Engineering", key: "eng")

    ISSUE_STATUSES.each_with_index do |(name, category), index|
      team.issue_statuses.find_or_create_by!(name: name) do |status|
        status.workspace = @workspace
        status.category = category
        status.position = index
      end
    end

    LABELS.each do |name, color|
      @workspace.labels.find_or_create_by!(name: name) { |label| label.color = color }
    end

    SAVED_VIEWS.each do |name, key, type|
      @workspace.saved_views.find_or_create_by!(key: key, team: team) do |view|
        view.name = name
        view.view_type = type
        view.filters = {}
      end
    end

    Catalog::Seeder.seed!(@workspace)
  end
end

class AutomationsController < AuthenticatedController
  TABS = %w[queue library triggers sandboxes].freeze

  def index
    @automation_tab = params[:tab].presence_in(TABS) || "queue"

    load_queue
    load_library
    load_triggers
    load_sandboxes
  end

  private

  def load_queue
    @runs = current_workspace.automation_runs
      .order(created_at: :desc)
      .limit(30)
      .to_a
    @attention_runs = @runs.select { |run| run.status.in?(%w[waiting_for_approval waiting_for_input failed]) }.first(6)
    @active_runs = @runs.select { |run| run.status.in?(%w[queued running]) }.first(6)
    @recent_runs = @runs.first(8)
    @change_requests = current_workspace.change_requests
      .includes(:issue, :pipeline_run, :repository_connection)
      .order(updated_at: :desc)
      .limit(8)
    run_scope = current_workspace.automation_runs
    @run_counts = {
      waiting: run_scope.where(status: "waiting_for_approval").count,
      active: run_scope.where(status: %w[queued running waiting_for_input]).count,
      failed: run_scope.where(status: %w[failed canceled]).count,
      completed: run_scope.where(status: "completed").count
    }
  end

  def load_library
    @pipelines = current_workspace.pipeline_definitions.order(:name, :version).to_a
    @actions = current_workspace.action_definitions.includes(:skill_definition, :agent_definition).order(:category, :name, :version).to_a
    @skills = current_workspace.skill_definitions.includes(:action_definitions).order(:category, :name, :version).to_a
    @agents = current_workspace.agent_definitions.includes(:action_definitions, :parent_agent_definition).order(:category, :name, :version).to_a
    @swarms = current_workspace.agent_swarm_definitions.includes(:coordinator_agent_definition, :agent_swarm_memberships).order(:category, :name, :version).to_a
    @pipeline_usage_counts = current_workspace.pipeline_runs
      .where(pipeline_definition_id: @pipelines.map(&:id))
      .group(:pipeline_definition_id)
      .count
    @swarm_usage_counts = current_workspace.agent_swarm_runs
      .where(agent_swarm_definition_id: @swarms.map(&:id))
      .group(:agent_swarm_definition_id)
      .count
    @favorite_pipelines = preferred_records(@pipelines, %w[cloud-rails-implement-issue implement-issue guided-implement-issue update-dependencies])
    @favorite_actions = preferred_records(@actions, %w[plan-story verify-plan code run-tests update-dependencies])
    @favorite_skills = preferred_records(@skills, %w[story-planning software-implementation cloud-sandbox-implementation incident-response])
    @favorite_agents = preferred_records(@agents, %w[planning-agent implementation-agent cloud-sandbox-agent verification-agent])
    @favorite_swarms = preferred_records(@swarms, %w[implementation-swarm cloud-sandbox-swarm maintenance-swarm])
    @library_counts = {
      pipelines: @pipelines.size,
      actions: @actions.size,
      skills: @skills.size,
      agents: @agents.size,
      swarms: @swarms.size
    }
  end

  def load_triggers
    @events = current_workspace.events.includes(:project, :issue).order(created_at: :desc).limit(10).to_a
    @rules = current_workspace.event_rules.includes(:pipeline_definition).order(active: :desc, name: :asc).to_a
    @schedules = current_workspace.schedules.includes(:pipeline_definition, :schedulable).order(created_at: :desc).limit(10).to_a
    @webhook_endpoint = "#{request.base_url}/webhooks/events/#{current_workspace.slug}/{source}"
    @trigger_counts = {
      events: @events.size,
      rules: @rules.size,
      schedules: @schedules.size,
      matched: @events.count { |event| @rules.any? { |rule| rule.matches?(event) } }
    }
  end

  def load_sandboxes
    @sandbox_usage = SandboxSession.open_usage_for(workspace: current_workspace, user: current_user)
    @projects = current_workspace.projects.order(:title)
    @open_sandbox_sessions = current_workspace.sandbox_sessions
      .open
      .includes(:project, :execution_environment, :pipeline_run, :sandbox_commands)
      .recent
      .limit(12)
    @pending_sandbox_runs = current_workspace.pipeline_runs
      .where(trigger: "sandbox", user: current_user, status: SandboxSession::ACTIVE_RUN_STATUSES)
      .where.not(id: @open_sandbox_sessions.select(:pipeline_run_id))
      .includes(:pipeline_definition, :project)
      .order(created_at: :desc)
      .limit(8)
    @recent_sandbox_sessions = current_workspace.sandbox_sessions
      .where.not(id: @open_sandbox_sessions.select(:id))
      .includes(:project, :execution_environment, :pipeline_run, :sandbox_commands)
      .recent
      .limit(8)
  end

  def preferred_records(records, keys)
    preferred = keys.filter_map { |key| records.find { |record| record.key == key } }
    (preferred + records).uniq.first(4)
  end
end

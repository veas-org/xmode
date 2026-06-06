class IssuesController < AuthenticatedController
  before_action :set_issue, only: %i[show edit update]
  before_action :set_event_context, only: %i[new create]

  def index
    @view = params[:view].presence || "inbox"
    @query = params[:q].to_s.strip
    base_scope = current_workspace.issues
      .includes(:team, :project, :cycle, :issue_status, :assignee, :pipeline_runs, :change_requests)
      .order(updated_at: :desc)
    @issue_counts = issue_counts(base_scope)
    @issues = base_scope
    @issues = @issues.where(assignee: current_user) if @view == "my"
    @issues = @issues.where(cycle: current_team.cycles.where(status: "active")) if @view == "active_cycle" && current_team
    @issues = @issues.joins(:issue_status).where(issue_statuses: { category: "backlog" }) if @view == "backlog"
    @issues = @issues.where("issues.title LIKE :query OR issues.identifier LIKE :query", query: "%#{@query}%") if @query.present?
    @selected_issue = selected_issue_for(@issues)
    @selected_runs = @selected_issue ? @selected_issue.pipeline_runs
      .includes(:pipeline_definition, :change_request, :run_messages, :run_logs, :approvals)
      .order(created_at: :desc)
      .limit(5) : []
    @selected_change_requests = @selected_issue ? @selected_issue.change_requests.includes(:repository_connection).order(updated_at: :desc).limit(3) : []
    @selected_recommended_pipelines = @selected_issue ? prioritized_issue_pipelines(current_workspace.pipeline_definitions.order(:name).to_a).first(2) : []
    @selected_conversation_items = @selected_issue ? issue_conversation_items(@selected_issue, @selected_runs, @selected_change_requests) : []
  end

  def show
    @runs = automation_runs_for(
      pipeline_runs: @issue.pipeline_runs,
      swarm_runs: @issue.agent_swarm_runs
    )
    @change_requests = @issue.change_requests
      .includes(:repository_connection, :pipeline_run)
      .order(updated_at: :desc)
    @events = @issue.events.order(updated_at: :desc).limit(5)
    @context_objectives = issue_context_records(:objectives)
    @context_plans = issue_context_records(:plan_records)
    @context_goals = issue_context_records(:goals)
    @recommended_pipelines = prioritized_issue_pipelines(current_workspace.pipeline_definitions.order(:name).to_a).first(3)
    @pipeline_count = current_workspace.pipeline_definitions.count
    @readiness_steps = issue_readiness_steps
  end

  def new
    @issue = current_workspace.issues.new(team: current_team, project_id: params[:project_id], cycle_id: params[:cycle_id])
    apply_event_defaults(@issue) if @event_context
  end

  def create
    @issue = current_workspace.issues.new(issue_params)
    @issue.team ||= current_team
    if @issue.save
      link_event_to_issue(@issue) if @event_context
      redirect_to @issue, notice: "Issue created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @issue.update(issue_params)
      redirect_to @issue, notice: "Issue updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_issue
    @issue = current_workspace.issues.find(params[:id])
  end

  def set_event_context
    event_id = params[:event_id].presence || params.dig(:issue, :event_id).presence
    @event_context = current_workspace.events.find_by(id: event_id) if event_id
  end

  def apply_event_defaults(issue)
    issue.project ||= @event_context.project
    issue.title = @event_context.title if issue.title.blank?
    issue.priority = event_priority(@event_context)
    issue.description = event_issue_description(@event_context) if issue.description.blank?
  end

  def link_event_to_issue(issue)
    @event_context.update!(issue: issue, status: "linked")
  end

  def event_priority(event)
    event.severity.in?(%w[critical error]) ? "urgent" : "medium"
  end

  def event_issue_description(event)
    <<~MARKDOWN
      ## Event source
      #{event.source} `#{event.event_type}` event #{event.id}

      ## Payload
      ```json
      #{JSON.pretty_generate(event.payload)}
      ```
    MARKDOWN
  end

  def issue_params
    params.require(:issue).permit(:title, :description, :team_id, :project_id, :cycle_id, :issue_status_id, :assignee_id, :parent_id, :priority, :estimate, :due_on)
  end

  def issue_counts(base_scope)
    {
      inbox: base_scope.count,
      my: base_scope.where(assignee: current_user).count,
      active_cycle: current_team ? base_scope.where(cycle: current_team.cycles.where(status: "active")).count : 0,
      backlog: base_scope.joins(:issue_status).where(issue_statuses: { category: "backlog" }).count
    }
  end

  def selected_issue_for(scope)
    selected = scope.find { |issue| issue.id.to_s == params[:selected].to_s } if params[:selected].present?
    selected || scope.first
  end

  def issue_conversation_items(issue, runs, change_requests)
    items = [
      {
        type: "issue",
        actor: issue.assignee&.display_name || "xmode",
        title: "#{issue.identifier} opened",
        content: issue.description.presence || "No objective or description has been captured yet.",
        status: issue.display_status,
        created_at: issue.created_at,
        markdown: true,
        href: issue_path(issue)
      }
    ]

    issue.events.order(created_at: :asc).limit(4).each do |event|
      items << {
        type: "event",
        actor: event.source.to_s.titleize,
        title: event.title,
        content: "#{event.event_type} · #{event.status}",
        status: event.severity,
        created_at: event.created_at,
        href: event_path(event)
      }
    end

    runs.each do |run|
      items << {
        type: "run",
        actor: "xmode",
        title: run.pipeline_definition&.name || "Pipeline run",
        content: "#{run.display_trigger} · #{run.display_status}",
        status: run.status,
        created_at: run.created_at,
        href: pipeline_run_path(run)
      }

      run.run_messages.order(:created_at).last(3).each do |message|
        items << {
          type: "message",
          actor: message.user&.display_name || message.role.to_s.titleize,
          title: message.kind.to_s.tr("_", " ").titleize,
          content: message.content,
          status: message.status,
          created_at: message.created_at,
          href: pipeline_run_path(run)
        }
      end

      run.approvals.order(:created_at).last(2).each do |approval|
        items << {
          type: "approval",
          actor: approval.user&.display_name || "Approval gate",
          title: approval.action_run_step&.name || "Manual approval",
          content: approval.notes.presence || approval.display_status,
          status: approval.status,
          created_at: approval.created_at,
          href: pipeline_run_path(run)
        }
      end

      run.run_logs.order(:created_at).last(3).each do |log|
        items << {
          type: "log",
          actor: "Run log",
          title: log.action_run_step&.name || log.level.to_s.titleize,
          content: log.message,
          status: log.level,
          created_at: log.created_at,
          href: pipeline_run_path(run)
        }
      end
    end

    change_requests.each do |change_request|
      items << {
        type: "change_request",
        actor: change_request.provider.to_s.titleize,
        title: change_request.title,
        content: "#{change_request.branch_name} · #{change_request.status.to_s.tr("_", " ")}",
        status: change_request.status,
        created_at: change_request.created_at,
        href: change_request_path(change_request)
      }
    end

    items.compact.sort_by { |item| item[:created_at] || Time.zone.at(0) }
  end

  def issue_context_records(association_name)
    records = @issue.public_send(association_name).order(updated_at: :desc).to_a
    records.concat(@issue.project.public_send(association_name).order(updated_at: :desc).to_a) if @issue.project
    records.uniq { |record| "#{record.class.name}-#{record.id}" }.first(4)
  end

  def automation_runs_for(pipeline_runs:, swarm_runs:)
    current_workspace.automation_runs
      .for_execution_scopes(pipeline_runs: pipeline_runs, swarm_runs: swarm_runs)
      .preload(:execution)
      .order(created_at: :desc)
  end

  def prioritized_issue_pipelines(pipelines)
    priority = %w[cloud-rails-implement-issue implement-issue guided-implement-issue fix-failing-build update-dependencies handle-production-event review-change-request release-project]
    pipelines.sort_by { |pipeline| [ priority.index(pipeline.key) || priority.size, pipeline.name ] }
  end

  def issue_readiness_steps
    [
      [ "Objective", @issue.description.present? ? "captured" : "missing" ],
      [ "Project", @issue.project.present? ? @issue.project.title : "unassigned" ],
      [ "Plan", @context_plans.any? ? "linked" : "needed" ],
      [ "Automation", @runs.any? ? "#{@runs.size} #{'run'.pluralize(@runs.size)}" : "not run" ],
      [ "Change Request", @change_requests.any? ? "#{@change_requests.size} CR" : "not opened" ]
    ]
  end
end

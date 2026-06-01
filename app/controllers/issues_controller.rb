class IssuesController < AuthenticatedController
  before_action :set_issue, only: %i[show edit update]
  before_action :set_event_context, only: %i[new create]

  def index
    @view = params[:view].presence || "inbox"
    @query = params[:q].to_s.strip
    base_scope = current_workspace.issues.includes(:team, :project, :cycle, :issue_status, :assignee).order(updated_at: :desc)
    @issue_counts = issue_counts(base_scope)
    @issues = base_scope
    @issues = @issues.where(assignee: current_user) if @view == "my"
    @issues = @issues.where(cycle: current_team.cycles.where(status: "active")) if @view == "active_cycle" && current_team
    @issues = @issues.joins(:issue_status).where(issue_statuses: { category: "backlog" }) if @view == "backlog"
    @issues = @issues.where("issues.title LIKE :query OR issues.identifier LIKE :query", query: "%#{@query}%") if @query.present?
    @selected_issue = @issues.first
  end

  def show
    @runs = @issue.pipeline_runs
      .includes(:pipeline_definition, :change_request, :approvals, :run_artifacts)
      .order(created_at: :desc)
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
      active_cycle: current_team ? base_scope.where(cycle: current_team.cycles.where(status: "active")).count : 0
    }
  end

  def issue_context_records(association_name)
    records = @issue.public_send(association_name).order(updated_at: :desc).to_a
    records.concat(@issue.project.public_send(association_name).order(updated_at: :desc).to_a) if @issue.project
    records.uniq { |record| "#{record.class.name}-#{record.id}" }.first(4)
  end

  def prioritized_issue_pipelines(pipelines)
    priority = %w[implement-issue fix-failing-build update-dependencies handle-production-event review-change-request release-project]
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

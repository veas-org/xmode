class SchedulesController < AuthenticatedController
  before_action :set_schedule, only: %i[show edit update]

  def index
    @schedules = current_workspace.schedules.includes(:pipeline_definition, :schedulable).order(created_at: :desc)
    @status_groups = @schedules.group_by(&:status).sort_by { |status, _schedules| status.to_s }
    @schedule_counts = {
      total: @schedules.size,
      active: @schedules.count { |schedule| schedule.status == "active" },
      recurring: @schedules.count { |schedule| schedule.kind == "recurring" },
      one_off: @schedules.count { |schedule| schedule.kind == "one_off" }
    }
  end

  def show
    @pipeline = @schedule.pipeline_definition
    @target = @schedule.schedulable
    @target_project = target_project
    @nodes = @pipeline.graph.fetch("nodes", [])
    @edges = @pipeline.graph.fetch("edges", [])
    actions = current_workspace
      .action_definitions
      .includes(:skill_definition)
      .where(key: @nodes.filter_map { |node| node["action_key"].to_s.split("@", 2).first })
      .to_a
    @actions_by_reference = actions.index_by(&:versioned_key)
    @actions_by_key = actions.group_by(&:key).transform_values { |records| Catalog::Versions.latest(records) }
    @recent_runs = recent_schedule_runs
    @change_requests = current_workspace
      .change_requests
      .includes(:issue, :pipeline_run, :repository_connection)
      .where(pipeline_run_id: @recent_runs.map(&:id))
      .order(updated_at: :desc)
    @trigger_rows = trigger_rows
    @safety_rows = safety_rows
  end

  def new
    @schedule = current_workspace.schedules.new(kind: "one_off", pipeline_definition_id: params[:pipeline_definition_id])
  end

  def create
    @schedule = current_workspace.schedules.new(schedule_params)
    if @schedule.save
      redirect_to @schedule, notice: "Schedule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @schedule.update(schedule_params)
      redirect_to @schedule, notice: "Schedule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_schedule
    @schedule = current_workspace.schedules.includes(:pipeline_definition, :schedulable).find(params[:id])
  end

  def schedule_params
    params.require(:schedule).permit(:pipeline_definition_id, :kind, :run_at, :cron, :status)
  end

  def recent_schedule_runs
    current_workspace
      .pipeline_runs
      .includes(:pipeline_definition, :issue, :project, :change_request, :run_artifacts)
      .where(pipeline_definition: @pipeline, trigger: %w[schedule recurring_schedule one_off_schedule])
      .order(created_at: :desc)
      .limit(30)
      .to_a
      .select { |run| run_belongs_to_schedule?(run) }
      .first(6)
  end

  def run_belongs_to_schedule?(run)
    return true if run.input_context.to_h["schedule_id"].to_s == @schedule.id.to_s
    return run.project_id.blank? && run.issue_id.blank? if @target.blank?

    case @target
    when Project
      run.project_id == @target.id
    when Issue
      run.issue_id == @target.id
    else
      false
    end
  end

  def target_project
    return @target if @target.is_a?(Project)
    return @target.project if @target.is_a?(Issue)

    nil
  end

  def trigger_rows
    [
      [ "Pipeline", @pipeline.name ],
      [ "Target", target_label ],
      [ "Cadence", @schedule.kind.tr("_", " ").titleize ],
      [ "Dispatch", dispatch_label ],
      [ "Status", @schedule.status.titleize ],
      [ "Frozen evidence", "#{@recent_runs.size} recent #{'run'.pluralize(@recent_runs.size)}" ]
    ]
  end

  def safety_rows
    manual_steps = @nodes.count do |node|
      action_for_node(node)&.provider == "manual"
    end
    [
      [ "Definition snapshot", "Pipeline and action definitions are frozen per run." ],
      [ "Code boundary", "New branch and Change Request for every code-changing schedule run." ],
      [ "Approval gates", manual_steps.positive? ? "#{manual_steps} manual #{'gate'.pluralize(manual_steps)}" : "No manual gate in graph" ],
      [ "Evidence ledger", "Logs, artifacts, checks, and Change Requests stay linked to the run." ]
    ]
  end

  def target_label
    @target&.try(:title) || @target&.try(:name) || "Workspace"
  end

  def dispatch_label
    @schedule.run_at&.strftime("%b %-d, %Y %-I:%M %p") || @schedule.cron
  end

  def action_for_node(node)
    reference = action_reference_for(node)
    @actions_by_reference[reference] || @actions_by_key[reference.to_s.split("@", 2).first]
  end
  helper_method :action_for_node

  def action_reference_for(node)
    key = node["action_key"].to_s
    version = node["action_version"].presence
    version.present? && key.exclude?("@") ? "#{key}@#{version}" : key
  end
end

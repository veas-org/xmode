class PipelineDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index home show export]
  before_action :set_pipeline, only: %i[show edit update export source update_source run]

  def home
    base_scope = current_workspace.pipeline_definitions
    @pipelines = base_scope.order(:name, :version).to_a
    pipeline_ids = @pipelines.map(&:id)
    @run_usage_counts = current_workspace.pipeline_runs.where(pipeline_definition_id: pipeline_ids).group(:pipeline_definition_id).count
    @schedule_counts = current_workspace.schedules.where(pipeline_definition_id: pipeline_ids).group(:pipeline_definition_id).count
    @event_rule_counts = current_workspace.event_rules.where(pipeline_definition_id: pipeline_ids).group(:pipeline_definition_id).count
    @recent_runs = current_workspace.pipeline_runs
      .includes(:pipeline_definition, :project, :issue, :event, :change_request)
      .where(pipeline_definition_id: pipeline_ids)
      .order(created_at: :desc)
      .limit(6)
    @latest_run_by_pipeline_id = current_workspace.pipeline_runs
      .where(pipeline_definition_id: pipeline_ids)
      .order(created_at: :desc)
      .to_a
      .each_with_object({}) { |run, latest| latest[run.pipeline_definition_id] ||= run }

    @query = catalog_query
    @source = params[:source].to_s
    @source = "" unless @source.in?(%w[built_in workspace])
    @trigger_options = @pipelines.flat_map { |pipeline| pipeline.triggers.presence || [ "manual" ] }.map(&:to_s).uniq.sort
    @trigger = params[:trigger].to_s
    @trigger = "" unless @trigger_options.include?(@trigger)

    filtered_pipelines = base_scope
    filtered_pipelines = filtered_pipelines.where(builtin: @source == "built_in") if @source.present?
    if @query.present?
      query = catalog_like_query(@query)
      filtered_pipelines = filtered_pipelines.where(
        "pipeline_definitions.name LIKE :query OR pipeline_definitions.key LIKE :query",
        query: query
      )
    end
    table_pipelines = filtered_pipelines.order(:name, :version).to_a
    table_pipelines.select! { |pipeline| (pipeline.triggers.presence || [ "manual" ]).map(&:to_s).include?(@trigger) } if @trigger.present?

    @favorite_pipelines = preferred_pipeline_home_records(@pipelines)
    @high_leverage_pipelines = high_leverage_pipelines(@pipelines)
    @stats = pipeline_home_stats(@pipelines)
    @table_pipelines, @pagination = paginate_catalog(table_pipelines)
  end

  def index
    @query = catalog_query
    base_scope = current_workspace.pipeline_definitions
    redirect_to pipelines_home_path and return if catalog_front_page?(:q, :source, :trigger, :page, :per_page)

    @source = params[:source].to_s
    @source = "" unless @source.in?(%w[built_in workspace])
    @trigger_options = base_scope.order(:name).flat_map { |pipeline| pipeline.triggers.presence || [ "manual" ] }.map(&:to_s).uniq.sort
    @trigger = params[:trigger].to_s
    @trigger = "" unless @trigger_options.include?(@trigger)

    pipelines = base_scope
    pipelines = pipelines.where(builtin: @source == "built_in") if @source.present?
    if @query.present?
      query = catalog_like_query(@query)
      pipelines = pipelines.where(
        "pipeline_definitions.name LIKE :query OR pipeline_definitions.key LIKE :query",
        query: query
      )
    end

    pipeline_records = pipelines.order(:name, :version).to_a
    pipeline_records.select! { |pipeline| (pipeline.triggers.presence || [ "manual" ]).map(&:to_s).include?(@trigger) } if @trigger.present?
    @pipelines, @pagination = paginate_catalog(pipeline_records)
  end

  def show
    prepare_pipeline_show
  end

  def new
    @pipeline_definition = current_workspace.pipeline_definitions.new(version: "1.0.0", graph: { nodes: [], edges: [] })
    @actions = current_workspace.action_definitions.order(:name, :version)
  end

  def new_import
  end

  def create
    @pipeline_definition = current_workspace.pipeline_definitions.new(pipeline_params)
    track_catalog_version(@pipeline_definition, source: "app")
    if @pipeline_definition.save
      redirect_to pipeline_path(@pipeline_definition), notice: "Pipeline created."
    else
      @actions = current_workspace.action_definitions.order(:name, :version)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @pipeline_definition = @pipeline
    @actions = current_workspace.action_definitions.order(:name, :version)
  end

  def source
  end

  def update
    track_catalog_version(@pipeline, source: "app")
    if @pipeline.update(pipeline_params)
      redirect_to pipeline_path(@pipeline), notice: "Pipeline updated."
    else
      @pipeline_definition = @pipeline
      @actions = current_workspace.action_definitions.order(:name, :version)
      render :edit, status: :unprocessable_entity
    end
  end

  def update_source
    Catalog::MarkdownCodec.assign_pipeline(@pipeline, params.require(:definition_markdown))
    track_catalog_version(@pipeline, source: "source")

    if @pipeline.save
      redirect_to pipeline_path(@pipeline), notice: "Pipeline source updated."
    else
      render :source, status: :unprocessable_entity
    end
  rescue ArgumentError, Psych::SyntaxError => e
    @pipeline.errors.add(:base, e.message)
    render :source, status: :unprocessable_entity
  end

  def import
    record = Catalog::YamlCodec.load_pipeline!(current_workspace, params.require(:catalog_yaml), source: "import", user: current_user)
    redirect_to pipeline_path(record), notice: "Pipeline imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to pipelines_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@pipeline), filename: "#{@pipeline.versioned_key}.yml", type: "application/x-yaml"
  end

  def run
    project = current_workspace.projects.find_by(id: params[:project_id])
    issue = issue_for_run(project)
    run = current_workspace.pipeline_runs.create!(
      pipeline_definition: @pipeline,
      user: current_user,
      project: project,
      issue: issue,
      event_id: params[:event_id],
      trigger: current_workspace.demo? ? "demo_agent" : "manual",
      input_context: input_context_params
    )
    if current_workspace.demo? && !cloud_sandbox_pipeline?(@pipeline)
      Pipelines::Runner.call(run)
    else
      PipelineRunnerJob.perform_later(run.id)
    end
    redirect_to pipeline_run_path(run), notice: "Pipeline run queued."
  end

  private

  def preferred_pipeline_home_records(pipelines)
    preferred_keys = %w[cloud-rails-implement-issue implement-issue guided-implement-issue update-dependencies handle-production-event]
    preferred = preferred_keys.filter_map { |key| pipelines.find { |pipeline| pipeline.key == key } }
    (preferred + pipelines).uniq.first(4)
  end

  def high_leverage_pipelines(pipelines)
    pipelines.sort_by do |pipeline|
      usage = pipeline_home_usage(pipeline)
      [ -usage, pipeline.name ]
    end.first(5)
  end

  def pipeline_home_stats(pipelines)
    {
      pipelines: pipelines.size,
      triggers: pipelines.flat_map { |pipeline| pipeline.triggers.presence || [ "manual" ] }.map(&:to_s).uniq.size,
      scheduled: pipelines.count { |pipeline| @schedule_counts.fetch(pipeline.id, 0).positive? },
      runs: @run_usage_counts.values.sum,
      event_rules: @event_rule_counts.values.sum
    }
  end

  def pipeline_home_usage(pipeline)
    @run_usage_counts.fetch(pipeline.id, 0) + @schedule_counts.fetch(pipeline.id, 0) + @event_rule_counts.fetch(pipeline.id, 0)
  end
  helper_method :pipeline_home_usage

  def set_pipeline
    @pipeline = current_workspace.pipeline_definitions.find(params[:id])
  end

  def prepare_pipeline_show
    load_catalog_navigation(active: @pipeline)
    @nodes = @pipeline.graph.fetch("nodes", [])
    @edges = @pipeline.graph.fetch("edges", [])
    actions = current_workspace.action_definitions.includes(:skill_definition).order(:name, :version).to_a
    @actions_by_reference = actions.index_by(&:versioned_key)
    @actions_by_key = actions.group_by(&:key).transform_values { |records| Catalog::Versions.latest(records) }
    @runs = @pipeline.pipeline_runs.order(created_at: :desc).limit(5)
    @schedules = @pipeline.schedules.order(updated_at: :desc)
    @event_rules = @pipeline.event_rules.order(:name)
    @catalog_versions = @pipeline.catalog_versions.order(created_at: :desc, revision: :desc).limit(8)
  end

  def pipeline_params
    raw = params.require(:pipeline_definition)
    attrs = raw.permit(:key, :name, :version, :builtin, triggers: [], permissions: [])
    attrs[:required_context] = parse_json(raw[:required_context_json], default: {})
    attrs[:graph] = parse_json(raw[:graph_json], default: { nodes: [], edges: [] }, fallback_to_raw: true)
    attrs
  end

  def input_context_params
    params.fetch(:input_context, {}).permit(:objective, :plan, :command, :issue_id, :project_id, :event_id).to_h
  end

  def cloud_sandbox_pipeline?(pipeline)
    pipeline&.required_context.to_h["cloud_sandbox"].present?
  end

  def issue_for_run(project)
    return current_workspace.issues.find_by(id: params[:issue_id]) if params[:issue_id].present?
    return unless current_workspace.demo? && project && input_context_params["objective"].present?

    current_workspace.issues.create!(
      team: project.team,
      project: project,
      assignee: current_user,
      title: input_context_params["objective"].to_s.truncate(120),
      description: <<~MARKDOWN,
        ## Objective

        #{input_context_params["objective"]}

        ## Demo source

        Created from the Planet Express governed agent scenario so the team can inspect the full xmode loop: objective, plan, action steps, logs, artifacts, approval, and Change Request.
      MARKDOWN
      priority: "medium"
    )
  end

  def parse_json(value, default:, fallback_to_raw: false)
    JSON.parse(value.presence || default.to_json)
  rescue JSON::ParserError
    fallback_to_raw ? value.to_s : default
  end
end

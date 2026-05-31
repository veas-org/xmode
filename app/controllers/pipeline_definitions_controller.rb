class PipelineDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index show export]
  before_action :set_pipeline, only: %i[show edit update export run]

  def index
    @pipelines = current_workspace.pipeline_definitions.order(:name)
  end

  def show
  end

  def new
    @pipeline_definition = current_workspace.pipeline_definitions.new(graph: { nodes: [], edges: [] })
  end

  def create
    @pipeline_definition = current_workspace.pipeline_definitions.new(pipeline_params)
    if @pipeline_definition.save
      redirect_to pipeline_path(@pipeline_definition), notice: "Pipeline created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @pipeline_definition = @pipeline
    @actions = current_workspace.action_definitions.order(:name)
  end

  def update
    if @pipeline.update(pipeline_params)
      redirect_to pipeline_path(@pipeline), notice: "Pipeline updated."
    else
      @pipeline_definition = @pipeline
      @actions = current_workspace.action_definitions.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def import
    record = Catalog::YamlCodec.load_pipeline!(current_workspace, params.require(:catalog_yaml))
    redirect_to pipeline_path(record), notice: "Pipeline imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to pipelines_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@pipeline), filename: "#{@pipeline.key}.yml", type: "application/x-yaml"
  end

  def run
    run = current_workspace.pipeline_runs.create!(
      pipeline_definition: @pipeline,
      user: current_user,
      project_id: params[:project_id],
      issue_id: params[:issue_id],
      event_id: params[:event_id],
      trigger: "manual",
      input_context: input_context_params
    )
    PipelineRunnerJob.perform_later(run.id)
    redirect_to pipeline_run_path(run), notice: "Pipeline run queued."
  end

  private

  def set_pipeline
    @pipeline = current_workspace.pipeline_definitions.find(params[:id])
  end

  def pipeline_params
    raw = params.require(:pipeline_definition)
    attrs = raw.permit(:key, :name, :builtin, triggers: [], permissions: [])
    attrs[:required_context] = parse_json(raw[:required_context_json], default: {})
    attrs[:graph] = parse_json(raw[:graph_json], default: { nodes: [], edges: [] })
    attrs
  end

  def input_context_params
    params.fetch(:input_context, {}).permit(:objective, :command, :issue_id, :project_id, :event_id).to_h
  end

  def parse_json(value, default:)
    JSON.parse(value.presence || default.to_json)
  rescue JSON::ParserError
    default
  end
end

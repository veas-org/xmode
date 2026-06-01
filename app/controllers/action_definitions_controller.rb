class ActionDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index show export]
  before_action :set_action, only: %i[show edit update export]

  def index
    @actions = current_workspace.action_definitions.order(:category, :name)
  end

  def show
    @linked_pipelines = current_workspace.pipeline_definitions.order(:name).select do |pipeline|
      pipeline.graph.fetch("nodes", []).any? do |node|
        node["action_key"] == @action.key || node["action_id"].to_i == @action.id
      end
    end
  end

  def new
    load_skills
    @action_definition = current_workspace.action_definitions.new(provider: "manual", category: "manual")
  end

  def new_import
  end

  def create
    @action_definition = current_workspace.action_definitions.new(action_params)
    if @action_definition.save
      redirect_to action_path(@action_definition), notice: "Action created."
    else
      load_skills
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_skills
    @action_definition = @action
  end

  def update
    if @action.update(action_params)
      redirect_to action_path(@action), notice: "Action updated."
    else
      load_skills
      @action_definition = @action
      render :edit, status: :unprocessable_entity
    end
  end

  def import
    record = Catalog::YamlCodec.load_action!(current_workspace, params.require(:catalog_yaml))
    redirect_to action_path(record), notice: "Action imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to actions_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@action), filename: "#{@action.key}.yml", type: "application/x-yaml"
  end

  private

  def set_action
    @action = current_workspace.action_definitions.find(params[:id])
  end

  def action_params
    raw = params.require(:action_definition)
    attrs = raw.permit(
      :key,
      :name,
      :category,
      :provider,
      :skill_definition_id,
      :timeout_seconds,
      :requires_objective,
      :plan_required_when_objective_unclear,
      :objective_template,
      :plan_template,
      :execution_guidance,
      :builtin,
      permissions: []
    )
    {
      input_schema: "input_schema_json",
      output_schema: "output_schema_json",
      defaults: "defaults_json",
      runtime_config: "runtime_config_json",
      retry_policy: "retry_policy_json",
      artifact_policy: "artifact_policy_json"
    }.each do |attribute, param_key|
      attrs[attribute] = parse_json(raw[param_key])
    end
    attrs[:best_practices] = raw[:best_practices_text].to_s.lines.map(&:strip).reject(&:blank?)
    attrs
  end

  def load_skills
    @skills = current_workspace.skill_definitions.order(:category, :name)
  end

  def parse_json(value)
    JSON.parse(value.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end

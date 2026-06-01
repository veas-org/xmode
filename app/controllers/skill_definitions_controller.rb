class SkillDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index show export]
  before_action :set_skill, only: %i[show edit update export]

  def index
    @skills = current_workspace.skill_definitions.includes(:action_definitions).order(:category, :name)
  end

  def show
    @actions = @skill.action_definitions.order(:category, :name)
  end

  def new
    @skill_definition = current_workspace.skill_definitions.new(category: "planning")
  end

  def new_import
  end

  def create
    @skill_definition = current_workspace.skill_definitions.new(skill_params)
    if @skill_definition.save
      redirect_to skill_path(@skill_definition), notice: "Skill created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @skill_definition = @skill
  end

  def update
    if @skill.update(skill_params)
      redirect_to skill_path(@skill), notice: "Skill updated."
    else
      @skill_definition = @skill
      render :edit, status: :unprocessable_entity
    end
  end

  def import
    record = Catalog::YamlCodec.load_skill!(current_workspace, params.require(:catalog_yaml))
    redirect_to skill_path(record), notice: "Skill imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to skills_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@skill), filename: "#{@skill.key}.yml", type: "application/x-yaml"
  end

  private

  def set_skill
    @skill = current_workspace.skill_definitions.find(params[:id])
  end

  def skill_params
    raw = params.require(:skill_definition)
    attrs = raw.permit(:key, :name, :category, :description, :instructions, :objective_template, :plan_template, :builtin)
    attrs[:input_schema] = parse_json(raw[:input_schema_json], default: {})
    attrs[:output_schema] = parse_json(raw[:output_schema_json], default: {})
    attrs[:metadata] = parse_json(raw[:metadata_json], default: {})
    attrs[:best_practices] = raw[:best_practices_text].to_s.lines.map(&:strip).reject(&:blank?)
    attrs
  end

  def parse_json(value, default:)
    JSON.parse(value.presence || default.to_json)
  rescue JSON::ParserError
    default
  end
end

class SkillDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index home show export]
  before_action :set_skill, only: %i[show edit update export source update_source release]

  def home
    skills = current_workspace.skill_definitions.includes(:action_definitions).order(:category, :name, :version)
    all_skills = skills.to_a

    @query = catalog_query
    @category_options = all_skills.map(&:category).uniq.sort
    @category = params[:category].to_s
    @category = "" unless @category_options.include?(@category)

    filtered_skills = skills
    filtered_skills = filtered_skills.where(category: @category) if @category.present?
    if @query.present?
      query = catalog_like_query(@query)
      filtered_skills = filtered_skills.where(
        "skill_definitions.name LIKE :query OR skill_definitions.key LIKE :query OR skill_definitions.version LIKE :query OR skill_definitions.description LIKE :query",
        query: query
      )
    end

    @favorite_skills = preferred_skill_home_records(all_skills)
    @stats = skill_home_stats(all_skills)
    @high_leverage_skills = all_skills.sort_by { |skill| [ -skill.action_definitions.size, skill.name ] }.first(5)
    @table_skills, @pagination = paginate_catalog(filtered_skills)
  end

  def index
    @query = catalog_query
    redirect_to skills_home_path and return if catalog_front_page?(:q, :category, :page, :per_page)

    @category_options = current_workspace.skill_definitions.distinct.order(:category).pluck(:category)
    @category = params[:category].to_s
    @category = "" unless @category_options.include?(@category)

    skills = current_workspace.skill_definitions.includes(:action_definitions)
    skills = skills.where(category: @category) if @category.present?
    if @query.present?
      query = catalog_like_query(@query)
      skills = skills.where(
        "skill_definitions.name LIKE :query OR skill_definitions.key LIKE :query OR skill_definitions.version LIKE :query OR skill_definitions.description LIKE :query",
        query: query
      )
    end

    @skills, @pagination = paginate_catalog(skills.order(:category, :name, :version))
  end

  def show
    prepare_skill_show
  end

  def new
    @skill_definition = current_workspace.skill_definitions.new(category: "planning", version: "1.0.0")
  end

  def new_import
  end

  def create
    @skill_definition = current_workspace.skill_definitions.new(skill_params)
    track_catalog_version(@skill_definition, source: "app")
    if @skill_definition.save
      redirect_to skill_path(@skill_definition), notice: "Skill created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @skill_definition = @skill
    @release_versions = release_versions_for(@skill)
  end

  def source
  end

  def update
    track_catalog_version(@skill, source: "app")
    if @skill.update(skill_params)
      redirect_to skill_path(@skill), notice: "Skill updated."
    else
      @skill_definition = @skill
      render :edit, status: :unprocessable_entity
    end
  end

  def update_source
    Catalog::MarkdownCodec.assign_skill(@skill, params.require(:definition_markdown))
    track_catalog_version(@skill, source: "source")

    if @skill.save
      redirect_to skill_path(@skill), notice: "Skill source updated."
    else
      render :source, status: :unprocessable_entity
    end
  rescue ArgumentError, Psych::SyntaxError => e
    @skill.errors.add(:base, e.message)
    render :source, status: :unprocessable_entity
  end

  def release
    released_skill = Catalog::SkillReleaser.call(@skill, level: params[:level], user: current_user, attributes: release_skill_params)
    redirect_to skill_path(released_skill), notice: "Released #{released_skill.versioned_key}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to edit_skill_path(@skill), alert: "Release failed: #{e.message}"
  end

  def import
    record = Catalog::YamlCodec.load_skill!(current_workspace, params.require(:catalog_yaml), source: "import", user: current_user)
    redirect_to skill_path(record), notice: "Skill imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to skills_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@skill), filename: "#{@skill.versioned_key}.yml", type: "application/x-yaml"
  end

  private

  def preferred_skill_home_records(skills)
    preferred_keys = %w[story-planning software-implementation code-review testing-strategy update-dependencies]
    preferred = preferred_keys.filter_map { |key| skills.find { |skill| skill.key == key } }
    (preferred + skills.to_a).uniq.first(4)
  end

  def skill_home_stats(skills)
    {
      skills: skills.size,
      categories: skills.map(&:category).uniq.size,
      actions: skills.sum { |skill| skill.action_definitions.size },
      versioned: skills.count { |skill| skill.version.present? }
    }
  end

  def set_skill
    @skill = current_workspace.skill_definitions.find(params[:id])
  end

  def prepare_skill_show
    load_catalog_navigation(active: @skill)
    @actions = @skill.action_definitions.order(:category, :name)
    @catalog_versions = @skill.catalog_versions.order(created_at: :desc, revision: :desc).limit(8)
  end

  def skill_params
    raw = params.require(:skill_definition)
    attrs = raw.permit(:key, :name, :version, :category, :description, :instructions, :objective_template, :plan_template, :builtin)
    attrs[:input_schema] = parse_json(raw[:input_schema_json], default: {})
    attrs[:output_schema] = parse_json(raw[:output_schema_json], default: {})
    attrs[:metadata] = parse_json(raw[:metadata_json], default: {})
    attrs[:best_practices] = raw[:best_practices_text].to_s.lines.map(&:strip).reject(&:blank?)
    attrs
  end

  def release_skill_params
    return {} unless params[:skill_definition].present?

    skill_params.except(:key, :version)
  end

  def parse_json(value, default:)
    JSON.parse(value.presence || default.to_json)
  rescue JSON::ParserError
    default
  end

  def release_versions_for(skill)
    Catalog::SkillReleaser::LEVELS.index_with do |level|
      Catalog::SkillReleaser.next_version(skill, level)
    end
  end
end

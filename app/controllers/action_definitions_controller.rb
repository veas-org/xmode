class ActionDefinitionsController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }, except: %i[index home show export]
  before_action :set_action, only: %i[show edit update export source update_source]

  def home
    base_scope = current_workspace.action_definitions
    @actions = base_scope.includes(:skill_definition, :agent_definition).order(:category, :name, :version).to_a
    @pipeline_usage_counts = action_pipeline_usage_counts(@actions)
    @run_usage_counts = ActionRunStep.where(action_definition_id: @actions.map(&:id)).group(:action_definition_id).count

    @query = catalog_query
    @category_options = @actions.map(&:category).uniq.sort
    @provider_options = @actions.map(&:provider).uniq.sort
    @category = params[:category].to_s
    @category = "" unless @category_options.include?(@category)
    @provider = params[:provider].to_s
    @provider = "" unless @provider_options.include?(@provider)

    filtered_actions = base_scope.left_joins(:skill_definition, :agent_definition).includes(:skill_definition, :agent_definition)
    filtered_actions = filtered_actions.where(category: @category) if @category.present?
    filtered_actions = filtered_actions.where(provider: @provider) if @provider.present?
    if @query.present?
      query = catalog_like_query(@query)
      filtered_actions = filtered_actions.where(
        "action_definitions.name LIKE :query OR action_definitions.key LIKE :query OR action_definitions.category LIKE :query OR action_definitions.provider LIKE :query OR skill_definitions.name LIKE :query OR skill_definitions.key LIKE :query OR agent_definitions.name LIKE :query OR agent_definitions.key LIKE :query",
        query: query
      )
    end

    @favorite_actions = preferred_action_home_records(@actions)
    @high_leverage_actions = high_leverage_actions(@actions)
    @stats = action_home_stats(@actions)
    @table_actions, @pagination = paginate_catalog(filtered_actions.order(:category, :name, :version))
  end

  def index
    @query = catalog_query
    base_scope = current_workspace.action_definitions
    redirect_to actions_home_path and return if catalog_front_page?(:q, :category, :provider, :page, :per_page)

    @category_options = base_scope.distinct.order(:category).pluck(:category)
    @provider_options = base_scope.distinct.order(:provider).pluck(:provider)
    @category = params[:category].to_s
    @category = "" unless @category_options.include?(@category)
    @provider = params[:provider].to_s
    @provider = "" unless @provider_options.include?(@provider)

    actions = base_scope.left_joins(:skill_definition, :agent_definition).includes(:skill_definition, :agent_definition)
    actions = actions.where(category: @category) if @category.present?
    actions = actions.where(provider: @provider) if @provider.present?
    if @query.present?
      query = catalog_like_query(@query)
      actions = actions.where(
        "action_definitions.name LIKE :query OR action_definitions.key LIKE :query OR action_definitions.category LIKE :query OR action_definitions.provider LIKE :query OR skill_definitions.name LIKE :query OR skill_definitions.key LIKE :query OR agent_definitions.name LIKE :query OR agent_definitions.key LIKE :query",
        query: query
      )
    end

    @actions, @pagination = paginate_catalog(actions.order(:category, :name, :version))
  end

  def show
    prepare_action_show
  end

  def new
    load_catalog_choices
    @action_definition = current_workspace.action_definitions.new(provider: "manual", category: "manual", version: "1.0.0")
  end

  def new_import
  end

  def create
    @action_definition = current_workspace.action_definitions.new(action_params)
    track_catalog_version(@action_definition, source: "app")
    if @action_definition.save
      redirect_to action_path(@action_definition), notice: "Action created."
    else
      load_catalog_choices
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_catalog_choices
    @action_definition = @action
  end

  def source
  end

  def update
    track_catalog_version(@action, source: "app")
    if @action.update(action_params)
      redirect_to action_path(@action), notice: "Action updated."
    else
      load_catalog_choices
      @action_definition = @action
      render :edit, status: :unprocessable_entity
    end
  end

  def update_source
    Catalog::MarkdownCodec.assign_action(@action, current_workspace, params.require(:definition_markdown))
    track_catalog_version(@action, source: "source")

    if @action.save
      redirect_to action_path(@action), notice: "Action source updated."
    else
      render :source, status: :unprocessable_entity
    end
  rescue ArgumentError, Psych::SyntaxError => e
    @action.errors.add(:base, e.message)
    render :source, status: :unprocessable_entity
  end

  def import
    record = Catalog::YamlCodec.load_action!(current_workspace, params.require(:catalog_yaml), source: "import", user: current_user)
    redirect_to action_path(record), notice: "Action imported."
  rescue ActiveRecord::RecordInvalid, KeyError, Psych::SyntaxError => e
    redirect_to actions_path, alert: "Import failed: #{e.message}"
  end

  def export
    send_data Catalog::YamlCodec.dump(@action), filename: "#{@action.versioned_key}.yml", type: "application/x-yaml"
  end

  private

  def preferred_action_home_records(actions)
    preferred_keys = %w[plan-story verify-plan code run-tests update-dependencies]
    preferred = preferred_keys.filter_map { |key| actions.find { |action| action.key == key } }
    (preferred + actions).uniq.first(4)
  end

  def high_leverage_actions(actions)
    actions.sort_by do |action|
      usage = @pipeline_usage_counts.fetch(action.id, 0) + @run_usage_counts.fetch(action.id, 0)
      [ -usage, action.name ]
    end.first(5)
  end

  def action_home_stats(actions)
    {
      actions: actions.size,
      categories: actions.map(&:category).uniq.size,
      providers: actions.map(&:provider).uniq.size,
      skill_bound: actions.count(&:skill_definition),
      agent_bound: actions.count(&:agent_definition)
    }
  end

  def action_home_usage(action)
    @pipeline_usage_counts.fetch(action.id, 0) + @run_usage_counts.fetch(action.id, 0)
  end
  helper_method :action_home_usage

  def action_pipeline_usage_counts(actions)
    actions_by_id = actions.index_by(&:id)
    actions_by_reference = actions.index_by(&:versioned_key)
    latest_actions_by_key = actions.group_by(&:key).transform_values { |records| Catalog::Versions.latest(records) }
    counts = Hash.new(0)

    current_workspace.pipeline_definitions.find_each do |pipeline|
      action_ids = pipeline.graph.fetch("nodes", []).filter_map do |node|
        action_reference = action_reference_for(node)
        actions_by_id[node["action_id"].to_i]&.id ||
          actions_by_reference[action_reference]&.id ||
          latest_actions_by_key[action_reference.to_s.split("@", 2).first]&.id
      end.uniq
      action_ids.each { |action_id| counts[action_id] += 1 }
    end

    counts
  end

  def set_action
    @action = current_workspace.action_definitions.find(params[:id])
  end

  def prepare_action_show
    load_catalog_navigation(active: @action)
    @linked_pipelines = current_workspace.pipeline_definitions.order(:name).select do |pipeline|
      pipeline.graph.fetch("nodes", []).any? do |node|
        node["action_id"].to_i == @action.id ||
          action_reference_for(node) == @action.versioned_key ||
          (node["action_version"].blank? && node["action_key"] == @action.key)
      end
    end
    @catalog_versions = @action.catalog_versions.order(created_at: :desc, revision: :desc).limit(8)
  end

  def action_params
    raw = params.require(:action_definition)
    attrs = raw.permit(
      :key,
      :name,
      :version,
      :category,
      :provider,
      :skill_definition_id,
      :agent_definition_id,
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

  def load_catalog_choices
    @skills = current_workspace.skill_definitions.order(:category, :name, :version)
    @agents = current_workspace.agent_definitions.order(:category, :name, :version)
  end

  def action_reference_for(node)
    key = node["action_key"].to_s
    version = node["action_version"].presence
    version.present? && key.exclude?("@") ? "#{key}@#{version}" : key
  end

  def parse_json(value)
    JSON.parse(value.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end

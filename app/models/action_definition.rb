class ActionDefinition < ApplicationRecord
  CATEGORIES = %w[planning coding verification review release incident maintenance manual].freeze
  PROVIDERS = %w[manual local_shell codex codex_cloud openai code_model local_model ollama anthropic claude github_actions gitlab_ci mcp].freeze
  SEMVER_PATTERN = CatalogVersioning::SEMVER_PATTERN

  include CatalogVersioning

  belongs_to :workspace, optional: true
  belongs_to :skill_definition, optional: true
  has_many :action_run_steps, dependent: :nullify

  before_validation :assign_default_objective_template

  validates :key, :name, :version, presence: true
  validates :key, uniqueness: { scope: %i[workspace_id version] }
  validates :category, inclusion: { in: CATEGORIES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :objective_template, presence: true, if: :requires_objective?
  validate :schemas_are_valid
  validate :best_practices_are_strings
  validate :skill_belongs_to_workspace

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  def input_context_for(pipeline_run)
    context = pipeline_run.input_context.deep_dup
    provided_objective = context["objective"].to_s.strip
    objective = provided_objective.presence || objective_from(pipeline_run)
    context["objective"] = objective if requires_objective?

    if plan_required_when_objective_unclear? && objective_unclear?(provided_objective)
      context["plan"] = context["plan"].presence || plan_from(pipeline_run)
    end

    context["skill"] = skill_context if skill_definition
    context["action"] = {
      "key" => key,
      "name" => name,
      "version" => version,
      "reference" => versioned_key,
      "guidance" => execution_guidance,
      "best_practices" => best_practices
    }
    context
  end

  private

  def schemas_are_valid
    [ [ :input_schema, input_schema ], [ :output_schema, output_schema ] ].each do |attribute, schema|
      JSONSchemer.schema(schema || {})
    rescue JSONSchemer::InvalidSchema => e
      errors.add(attribute, e.message)
    end
  end

  def best_practices_are_strings
    return if best_practices.is_a?(Array) && best_practices.all? { |item| item.is_a?(String) }

    errors.add(:best_practices, "must be a list of text best practices")
  end

  def skill_belongs_to_workspace
    return if skill_definition.blank? || skill_definition.workspace_id.blank? || skill_definition.workspace_id == workspace_id

    errors.add(:skill_definition, "must belong to the same workspace")
  end

  def assign_default_objective_template
    return unless requires_objective?

    self.objective_template = "Complete {{action}} for {{issue}} {{issue_title}} in {{project}}." if objective_template.blank?
  end

  def objective_unclear?(objective)
    objective.blank? || objective.split.size < 4
  end

  def objective_from(pipeline_run)
    render_template(
      objective_template.presence || skill_definition&.objective_template,
      pipeline_run
    ).presence || "Complete #{name} for #{pipeline_run.issue&.identifier || pipeline_run.project&.title || "this run"}."
  end

  def plan_from(pipeline_run)
    render_template(
      plan_template.presence || skill_definition&.plan_template,
      pipeline_run
    ).presence || "Clarify the objective, inspect inputs and constraints, execute the action, validate outputs, and record evidence."
  end

  def render_template(template, pipeline_run)
    template.to_s
      .gsub("{{action}}", name.to_s)
      .gsub("{{skill}}", skill_definition&.name.to_s)
      .gsub("{{issue}}", pipeline_run.issue&.identifier.to_s)
      .gsub("{{issue_title}}", pipeline_run.issue&.title.to_s)
      .gsub("{{project}}", pipeline_run.project&.title.to_s)
      .gsub("{{run}}", pipeline_run.id.to_s)
  end

  def skill_context
    {
      "key" => skill_definition.key,
      "name" => skill_definition.name,
      "version" => skill_definition.version,
      "reference" => skill_definition.versioned_key,
      "category" => skill_definition.category,
      "instructions" => skill_definition.instructions,
      "best_practices" => skill_definition.best_practices
    }
  end
end

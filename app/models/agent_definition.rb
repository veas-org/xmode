require "set"

class AgentDefinition < ApplicationRecord
  CATEGORIES = (SkillDefinition::CATEGORIES + %w[coordination]).uniq.freeze
  RUNTIMES = %w[model codex codex_cloud local_model local_shell manual].freeze

  include CatalogVersioning

  belongs_to :workspace, optional: true
  belongs_to :parent_agent_definition, class_name: "AgentDefinition", optional: true
  has_many :child_agent_definitions, class_name: "AgentDefinition", foreign_key: :parent_agent_definition_id, dependent: :nullify, inverse_of: :parent_agent_definition
  has_many :action_definitions, dependent: :nullify
  has_many :agent_swarm_memberships, dependent: :destroy
  has_many :agent_swarm_definitions, through: :agent_swarm_memberships
  has_many :coordinated_agent_swarms, class_name: "AgentSwarmDefinition", foreign_key: :coordinator_agent_definition_id, dependent: :nullify, inverse_of: :coordinator_agent_definition

  validates :key, :name, :version, :category, :runtime, presence: true
  validates :key, uniqueness: { scope: %i[workspace_id version] }
  validates :category, inclusion: { in: CATEGORIES }
  validates :runtime, inclusion: { in: RUNTIMES }
  validate :tools_are_a_list
  validate :settings_are_an_object
  validate :metadata_is_an_object
  validate :parent_belongs_to_workspace
  validate :parent_lineage_is_acyclic
  validate :effective_system_prompt_present

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  def effective_system_prompt(seen_ids = Set.new)
    return "" if id.present? && seen_ids.include?(id)

    seen_ids.add(id) if id.present?
    parts = [
      parent_agent_definition&.effective_system_prompt(seen_ids),
      system_prompt,
      system_prompt_append
    ].map { |part| part.to_s.strip }.reject(&:blank?)
    parts.join("\n\n")
  end

  def execution_context
    {
      "key" => key,
      "name" => name,
      "version" => version,
      "reference" => versioned_key,
      "category" => category,
      "runtime" => runtime,
      "model" => model,
      "system_prompt" => effective_system_prompt,
      "tools" => tools,
      "settings" => settings,
      "parent_reference" => parent_agent_definition&.versioned_key
    }.compact
  end

  private

  def tools_are_a_list
    return if tools.is_a?(Array)

    errors.add(:tools, "must be a list")
  end

  def settings_are_an_object
    return if settings.is_a?(Hash)

    errors.add(:settings, "must be an object")
  end

  def metadata_is_an_object
    return if metadata.is_a?(Hash)

    errors.add(:metadata, "must be an object")
  end

  def parent_belongs_to_workspace
    return if parent_agent_definition.blank? || parent_agent_definition.workspace_id.blank? || parent_agent_definition.workspace_id == workspace_id

    errors.add(:parent_agent_definition, "must belong to the same workspace")
  end

  def parent_lineage_is_acyclic
    return if parent_agent_definition.blank? || id.blank?

    ancestor = parent_agent_definition
    while ancestor
      if ancestor.id == id
        errors.add(:parent_agent_definition, "cannot create an inheritance cycle")
        break
      end
      ancestor = ancestor.parent_agent_definition
    end
  end

  def effective_system_prompt_present
    return if effective_system_prompt.present?

    errors.add(:system_prompt, "must be present or inherited from a parent agent")
  end
end

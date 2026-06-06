class AgentSwarmDefinition < ApplicationRecord
  CATEGORIES = AgentDefinition::CATEGORIES
  STRATEGIES = %w[coordinated parallel review_board handoff].freeze

  include CatalogVersioning

  belongs_to :workspace, optional: true
  belongs_to :coordinator_agent_definition, class_name: "AgentDefinition", optional: true
  has_many :agent_swarm_memberships, -> { order(:position, :id) }, dependent: :destroy
  has_many :agent_definitions, through: :agent_swarm_memberships
  has_many :agent_swarm_runs, dependent: :nullify

  validates :key, :name, :version, :category, :strategy, presence: true
  validates :key, uniqueness: { scope: %i[workspace_id version] }
  validates :category, inclusion: { in: CATEGORIES }
  validates :strategy, inclusion: { in: STRATEGIES }
  validate :metadata_is_an_object
  validate :coordinator_belongs_to_workspace

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  def execution_context
    {
      "key" => key,
      "name" => name,
      "version" => version,
      "reference" => versioned_key,
      "category" => category,
      "strategy" => strategy,
      "coordination_prompt" => coordination_prompt,
      "coordinator_agent" => coordinator_agent_definition&.execution_context,
      "members" => agent_swarm_memberships.map(&:execution_context)
    }.compact
  end

  private

  def metadata_is_an_object
    return if metadata.is_a?(Hash)

    errors.add(:metadata, "must be an object")
  end

  def coordinator_belongs_to_workspace
    return if coordinator_agent_definition.blank? || coordinator_agent_definition.workspace_id.blank? || coordinator_agent_definition.workspace_id == workspace_id

    errors.add(:coordinator_agent_definition, "must belong to the same workspace")
  end
end

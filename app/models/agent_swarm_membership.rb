class AgentSwarmMembership < ApplicationRecord
  ROLES = %w[coordinator planner implementer verifier reviewer member].freeze

  belongs_to :agent_swarm_definition
  belongs_to :agent_definition

  validates :role, inclusion: { in: ROLES }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validate :settings_are_an_object
  validate :agent_belongs_to_swarm_workspace

  def execution_context
    {
      "role" => role,
      "position" => position,
      "instructions_append" => instructions_append,
      "settings" => settings,
      "agent" => agent_definition.execution_context
    }.compact
  end

  private

  def settings_are_an_object
    return if settings.is_a?(Hash)

    errors.add(:settings, "must be an object")
  end

  def agent_belongs_to_swarm_workspace
    swarm_workspace_id = agent_swarm_definition&.workspace_id
    return if agent_definition.blank? || agent_definition.workspace_id.blank? || agent_definition.workspace_id == swarm_workspace_id

    errors.add(:agent_definition, "must belong to the same workspace")
  end
end

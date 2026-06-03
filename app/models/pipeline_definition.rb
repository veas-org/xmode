require "set"

class PipelineDefinition < ApplicationRecord
  INTERACTIVE_NODE_TYPES = %w[decision follow_up goal_check].freeze
  SEMVER_PATTERN = CatalogVersioning::SEMVER_PATTERN

  include CatalogVersioning

  belongs_to :workspace, optional: true

  has_many :pipeline_runs, dependent: :nullify
  has_many :event_rules, dependent: :nullify
  has_many :schedules, dependent: :destroy

  validates :key, :name, :version, presence: true
  validates :key, uniqueness: { scope: %i[workspace_id version] }
  validate :graph_shape

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  private

  def graph_shape
    unless graph.is_a?(Hash)
      errors.add(:graph, "must be valid JSON")
      return
    end

    nodes = read(graph, "nodes")
    edges = read(graph, "edges")

    unless nodes.is_a?(Array)
      errors.add(:graph, "nodes must be an array")
      return
    end

    unless edges.is_a?(Array)
      errors.add(:graph, "edges must be an array")
      return
    end

    validate_nodes(nodes)
    validate_edges(edges, nodes)
  end

  def validate_nodes(nodes)
    seen_ids = Set.new

    nodes.each_with_index do |node, index|
      unless node.is_a?(Hash)
        errors.add(:graph, "node #{index + 1} must be an object")
        next
      end

      node_id = read(node, "id").to_s.strip
      if node_id.blank?
        errors.add(:graph, "node #{index + 1} must include an id")
      elsif seen_ids.include?(node_id)
        errors.add(:graph, "node id #{node_id} is duplicated")
      else
        seen_ids.add(node_id)
      end

      validate_node_contract(node, index)
    end
  end

  def validate_node_contract(node, index)
    node_type = read(node, "type").presence || "action"

    if node_type == "action"
      validate_action_node(node, index)
    elsif INTERACTIVE_NODE_TYPES.include?(node_type)
      validate_interactive_node(node, index, node_type)
    else
      errors.add(:graph, "node #{index + 1} has unknown type #{node_type}")
    end
  end

  def validate_action_node(node, index)
    action_key = read(node, "action_key").to_s.strip
    action_id = read(node, "action_id").presence

    if action_key.blank? && action_id.blank?
      errors.add(:graph, "action node #{index + 1} must reference an action")
      return
    end

    action = action_for(action_key, action_id)
    errors.add(:graph, "action node #{index + 1} references an unknown action") if action.blank?
  end

  def validate_interactive_node(node, index, node_type)
    question = read(node, "question").presence || read(node, "prompt").presence
    errors.add(:graph, "#{node_type.humanize} node #{index + 1} must include a question or prompt") if question.blank?

    case node_type
    when "decision"
      validate_choices(node, index, required: true)
    when "goal_check"
      validate_goal_checks(node, index)
      validate_choices(node, index, required: false)
    end
  end

  def validate_choices(node, index, required:)
    choices = read(node, "choices")
    if choices.blank?
      errors.add(:graph, "decision node #{index + 1} must include choices") if required
      return
    end

    unless choices.is_a?(Array)
      errors.add(:graph, "node #{index + 1} choices must be an array")
      return
    end

    choices.each_with_index do |choice, choice_index|
      unless choice.is_a?(Hash) && read(choice, "key").to_s.strip.present?
        errors.add(:graph, "node #{index + 1} choice #{choice_index + 1} must include a key")
      end
    end
  end

  def validate_goal_checks(node, index)
    checks = read(node, "checks")
    unless checks.is_a?(Array) && checks.any? && checks.all? { |check| check.to_s.strip.present? }
      errors.add(:graph, "Goal check node #{index + 1} must include checks")
    end
  end

  def validate_edges(edges, nodes)
    node_ids = nodes.filter_map { |node| read(node, "id").to_s if node.is_a?(Hash) }.to_set
    seen_edge_ids = Set.new

    edges.each_with_index do |edge, index|
      unless edge.is_a?(Hash)
        errors.add(:graph, "edge #{index + 1} must be an object")
        next
      end

      edge_id = read(edge, "id").to_s.strip
      if edge_id.present? && seen_edge_ids.include?(edge_id)
        errors.add(:graph, "edge id #{edge_id} is duplicated")
      else
        seen_edge_ids.add(edge_id) if edge_id.present?
      end

      from_id = read(edge, "from").to_s.strip
      to_id = read(edge, "to").to_s.strip

      errors.add(:graph, "edge #{index + 1} must include from") if from_id.blank?
      errors.add(:graph, "edge #{index + 1} must include to") if to_id.blank?
      errors.add(:graph, "edge #{index + 1} references an unknown source node") if from_id.present? && !node_ids.include?(from_id)
      errors.add(:graph, "edge #{index + 1} references an unknown target node") if to_id.present? && !node_ids.include?(to_id)
      errors.add(:graph, "edge #{index + 1} cannot connect a node to itself") if from_id.present? && from_id == to_id
    end
  end

  def action_for(action_key, action_id)
    key, version = parse_action_reference(action_key)
    scope = if workspace_id.present?
      ActionDefinition.where(workspace_id: [ workspace_id, nil ])
    else
      ActionDefinition.where(workspace_id: nil)
    end

    if action_id.present?
      action = scope.find_by(id: action_id)
      return action if key.blank? || action_matches?(action, key, version)
    end

    scope = scope.where(key: key) if key.present?
    scope = scope.where(version: version) if version.present?
    return unless key.present?

    version.present? ? scope.order(id: :desc).first : Catalog::Versions.latest(scope.to_a)
  end

  def action_matches?(action, key, version)
    action.present? && action.key == key && (version.blank? || action.version == version)
  end

  def parse_action_reference(reference)
    key, version = reference.to_s.strip.split("@", 2)
    [ key, version.presence ]
  end

  def read(value, key)
    return unless value.respond_to?(:[])

    return value[key.to_s] if value.respond_to?(:key?) && value.key?(key.to_s)
    return value[key.to_sym] if value.respond_to?(:key?) && value.key?(key.to_sym)

    value[key.to_s] || value[key.to_sym]
  end
end

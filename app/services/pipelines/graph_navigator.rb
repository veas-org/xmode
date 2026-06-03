module Pipelines
  class GraphNavigator
    def initialize(graph)
      @graph = graph || {}
    end

    def nodes
      Array(read(@graph, "nodes"))
    end

    def node_index(node_id)
      nodes.index { |node| read(node, "id").to_s == node_id.to_s }
    end

    def next_index_for(node, output, fallback_index, step_status: nil)
      next_id = next_node_id_for(node, output, step_status: step_status)
      return node_index(next_id) if next_id.present? && node_index(next_id)

      fallback_index
    end

    def next_node_id_for(node, output, step_status: nil)
      explicit_next = read(output, "next").presence
      return explicit_next if explicit_next.present?

      matching_edge = outgoing_edges_for(node).find do |edge|
        conditions_for(output, step_status: step_status).include?(read(edge, "condition").to_s)
      end
      matching_edge ||= outgoing_edges_for(node).find { |edge| read(edge, "condition").blank? }
      read(matching_edge, "to")
    end

    private

    def outgoing_edges_for(node)
      node_id = read(node, "id").to_s
      Array(read(@graph, "edges")).select { |edge| read(edge, "from").to_s == node_id }
    end

    def conditions_for(output, step_status:)
      conditions = []
      choice = read(output, "choice").presence
      action = read(output, "action").presence
      status = read(output, "status").presence
      kind = read(output, "kind").presence

      conditions << "choice:#{choice}" if choice
      conditions << choice if choice
      conditions << action if action
      conditions << status if status
      conditions << step_status if step_status
      conditions << "approved" if action == "approve"
      conditions << "rejected" if action == "reject"
      conditions << "failed" if step_status == "failed" || status == "failed"
      conditions << "success" if step_status == "completed" || status.in?(%w[completed success])
      conditions << "answered" if kind.present? || choice.present?

      conditions.compact.map(&:to_s).reject(&:blank?).uniq
    end

    def read(value, key)
      return unless value.respond_to?(:[])

      return value[key.to_s] if value.respond_to?(:key?) && value.key?(key.to_s)
      return value[key.to_sym] if value.respond_to?(:key?) && value.key?(key.to_sym)

      value[key.to_s] || value[key.to_sym]
    end
  end
end

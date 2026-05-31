class PipelineDefinition < ApplicationRecord
  belongs_to :workspace, optional: true

  has_many :pipeline_runs, dependent: :nullify
  has_many :event_rules, dependent: :nullify
  has_many :schedules, dependent: :destroy

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }
  validate :graph_shape

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  private

  def graph_shape
    unless graph.is_a?(Hash) && graph.key?("nodes") && graph.key?("edges")
      errors.add(:graph, "must include nodes and edges")
    end
  end
end

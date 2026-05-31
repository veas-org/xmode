class ActionDefinition < ApplicationRecord
  CATEGORIES = %w[planning coding verification review release incident maintenance manual].freeze
  PROVIDERS = %w[manual local_shell codex openai claude github_actions gitlab_ci mcp].freeze

  belongs_to :workspace, optional: true
  has_many :action_run_steps, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }
  validates :category, inclusion: { in: CATEGORIES }
  validates :provider, inclusion: { in: PROVIDERS }
  validate :schemas_are_valid

  def snapshot
    attributes.except("created_at", "updated_at").as_json
  end

  private

  def schemas_are_valid
    [ [ :input_schema, input_schema ], [ :output_schema, output_schema ] ].each do |attribute, schema|
      JSONSchemer.schema(schema || {})
    rescue JSONSchemer::InvalidSchema => e
      errors.add(attribute, e.message)
    end
  end
end

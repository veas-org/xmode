class SkillDefinition < ApplicationRecord
  CATEGORIES = %w[planning coding verification review release incident maintenance manual].freeze

  belongs_to :workspace, optional: true
  has_many :action_definitions, dependent: :nullify

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :workspace_id }
  validates :category, inclusion: { in: CATEGORIES }
  validate :schemas_are_valid
  validate :best_practices_are_strings

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

  def best_practices_are_strings
    return if best_practices.is_a?(Array) && best_practices.all? { |item| item.is_a?(String) }

    errors.add(:best_practices, "must be a list of text best practices")
  end
end

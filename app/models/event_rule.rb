class EventRule < ApplicationRecord
  belongs_to :workspace
  belongs_to :pipeline_definition, optional: true

  validates :name, presence: true

  def matches?(event)
    return false unless active?
    return false if source.present? && source != event.source
    return false if event_type.present? && event_type != event.event_type

    conditions.all? do |key, expected|
      event.normalized[key.to_s] == expected || event.payload[key.to_s] == expected
    end
  end
end

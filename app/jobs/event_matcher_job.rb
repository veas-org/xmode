class EventMatcherJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find(event_id)
    Events::RuleMatcher.call(event)
  end
end

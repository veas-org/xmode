module Events
  class RuleMatcher
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      @event.workspace.event_rules.includes(:pipeline_definition).select { |rule| rule.matches?(@event) }.each do |rule|
        next unless rule.pipeline_definition

        PipelineRun.create!(
          workspace: @event.workspace,
          pipeline_definition: rule.pipeline_definition,
          event: @event,
          trigger: "event_rule",
          input_context: { event_id: @event.id, rule_id: rule.id }
        )
      end
    end
  end
end

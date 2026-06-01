module Events
  class RuleMatcher
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      @event.workspace.event_rules.includes(:pipeline_definition).select { |rule| rule.matches?(@event) }.filter_map do |rule|
        next unless rule.pipeline_definition

        PipelineRun.create!(
          workspace: @event.workspace,
          pipeline_definition: rule.pipeline_definition,
          event: @event,
          project: @event.project,
          issue: @event.issue,
          trigger: "event_rule",
          input_context: input_context_for(rule)
        )
      end
    end

    private

    def input_context_for(rule)
      {
        "event_id" => @event.id,
        "rule_id" => rule.id,
        "source" => @event.source,
        "event_type" => @event.event_type,
        "event_title" => @event.title,
        "severity" => @event.severity,
        "target" => target_context
      }
    end

    def target_context
      {
        "workspace_id" => @event.workspace_id,
        "project_id" => @event.project_id,
        "project_key" => @event.project&.key,
        "issue_id" => @event.issue_id,
        "issue_identifier" => @event.issue&.identifier
      }.compact
    end
  end
end

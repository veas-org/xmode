class EventRulesController < AuthenticatedController
  before_action -> { require_permission!("manage_pipelines") }
  before_action :set_event_rule, only: %i[edit update]

  def new
    @event_rule = current_workspace.event_rules.new(
      active: true,
      pipeline_definition_id: params[:pipeline_definition_id],
      source: params[:source],
      event_type: params[:event_type]
    )
    prepare_form
  end

  def create
    @event_rule = current_workspace.event_rules.new
    assign_rule_attributes(@event_rule)

    if @event_rule.save
      audit!("event_rule.created")
      redirect_to events_path, notice: "Event rule created."
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_form
  end

  def update
    assign_rule_attributes(@event_rule)

    if @event_rule.save
      audit!("event_rule.updated")
      redirect_to events_path, notice: "Event rule updated."
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_event_rule
    @event_rule = current_workspace.event_rules.find(params[:id])
  end

  def prepare_form
    @pipelines = current_workspace.pipeline_definitions.order(:name)
    @conditions_text = conditions_text_for(@event_rule)
  end

  def assign_rule_attributes(rule)
    rule.name = event_rule_value(:name)
    rule.source = event_rule_value(:source)
    rule.event_type = event_rule_value(:event_type)
    rule.active = ActiveModel::Type::Boolean.new.cast(event_rule_value(:active))
    rule.pipeline_definition = current_workspace.pipeline_definitions.find_by(id: event_rule_value(:pipeline_definition_id))
    rule.conditions = parsed_conditions
  end

  def event_rule_value(key)
    params.dig(:event_rule, key).to_s.strip
  end

  def parsed_conditions
    event_rule_value(:conditions_text).lines.each_with_object({}) do |line, conditions|
      key, value = line.strip.split(/[=:]/, 2)
      next if key.blank? || value.blank?

      conditions[key.strip] = value.strip
    end
  end

  def conditions_text_for(rule)
    rule.conditions.to_h.map { |key, value| "#{key}=#{value}" }.join("\n")
  end

  def audit!(action)
    Audit::Recorder.call(
      workspace: current_workspace,
      user: current_user,
      auditable: @event_rule,
      action: action,
      source: "app",
      metadata: {
        name: @event_rule.name,
        source: @event_rule.source,
        event_type: @event_rule.event_type,
        pipeline: @event_rule.pipeline_definition&.name,
        active: @event_rule.active?
      }.compact,
      request: request
    )
  end
end

require "set"

module Pipelines
  class Runner
    def self.call(pipeline_run)
      new(pipeline_run).call
    end

    def initialize(pipeline_run)
      @pipeline_run = pipeline_run
      @navigator = GraphNavigator.new(pipeline_run.pipeline_snapshot.fetch("graph", {}))
    end

    def call
      @pipeline_run.update!(status: "running", started_at: Time.current)
      @pipeline_run.append_log("Pipeline started")
      audit!("pipeline_run.started", metadata: run_metadata)
      @resume_node_id = @pipeline_run.input_context.dig("_runner", "resume_node_id")
      index = resume_index || 0
      clear_resume_pointer
      visited_indexes = Set.new
      while index < nodes.size
        break if visited_indexes.include?(index)

        visited_indexes << index
        node = nodes[index]
        run_node(node, index)
        break if @pipeline_run.reload.status.in?(%w[waiting_for_approval waiting_for_input])

        index = next_index_for(node, index)
      end
      finish_if_ready
    rescue => e
      @pipeline_run.append_log(e.message, level: "error")
      @pipeline_run.update!(status: "failed", error_message: e.message, finished_at: Time.current)
      Billing::UsageRecorder.call(@pipeline_run)
      audit!("pipeline_run.failed", severity: "error", metadata: run_metadata.merge(error: e.message))
    end

    private

    def nodes
      @pipeline_run.pipeline_snapshot.fetch("graph", {}).fetch("nodes", [])
    end

    def run_node(node, index)
      return run_interaction_node(node, index) if interaction_node?(node)

      existing = @pipeline_run.action_run_steps.find_by(position: index)
      return if existing&.status == "completed"

      action = action_for(node)
      step = existing || @pipeline_run.action_run_steps.create!(
        action_definition: action,
        name: node["label"].presence || action&.name || "Action",
        position: index,
        input_json: action&.input_context_for(@pipeline_run) || @pipeline_run.input_context,
        status: "running"
      )

      return if existing&.status.in?(%w[waiting_for_approval waiting_for_input])
      step.update!(status: "running") unless step.status == "running"

      if action&.provider == "manual"
        step.update!(status: "waiting_for_approval")
        @pipeline_run.approvals.create!(action_run_step: step, status: "pending")
        @pipeline_run.run_messages.create!(
          action_run_step: step,
          role: "assistant",
          kind: "choice_question",
          status: "pending",
          content: "#{step.name} needs a decision before the run can continue.",
          payload: {
            "choices" => [
              { "key" => "approve", "label" => "Approve", "action" => "approve" },
              { "key" => "revise", "label" => "Revise plan", "action" => "follow_up" },
              { "key" => "reject", "label" => "Reject", "action" => "reject" }
            ]
          }
        )
        @pipeline_run.append_log("#{step.name} is waiting for approval", step: step)
        @pipeline_run.update!(status: "waiting_for_approval")
      elsif action&.provider == "local_shell"
        output = Runners::LocalShell.call(step)
        if output["status"] == "failed"
          step.update!(status: "failed", output_json: output, error_message: output["summary"], finished_at: Time.current)
          ensure_change_request_for_changed_files!(output, step)
          raise output["summary"]
        else
          step.update!(status: "completed", output_json: output, finished_at: Time.current)
          ensure_change_request_for_changed_files!(output, step)
        end
      else
        output = Providers::Registry.call(action.provider, step)
        if output["status"] == "needs_input"
          step.update!(status: "waiting_for_input", output_json: output)
          @pipeline_run.append_log("#{step.name} is waiting for provider follow-up", step: step)
          @pipeline_run.update!(status: "waiting_for_input")
        elsif output["status"] == "failed"
          step.update!(status: "failed", output_json: output, error_message: output["summary"], finished_at: Time.current)
          ensure_change_request_for_changed_files!(output, step)
          raise output["summary"]
        else
          step.update!(status: "completed", output_json: output, finished_at: Time.current)
          ensure_change_request_for_changed_files!(output, step)
        end
      end
    end

    def ensure_change_request_for_changed_files!(output, step)
      return unless output.to_h["changed_files_count"].to_i.positive?
      return if @pipeline_run.reload.change_request.present?

      ChangeRequests::Builder.call(@pipeline_run, step)
      @pipeline_run.append_log("Code-changing output created a Change Request", step: step)
    end

    def action_for(node)
      scope = @pipeline_run.workspace.action_definitions
      action_id = read(node, "action_id").presence
      key, version = parse_action_reference(read(node, "action_key"), read(node, "action_version"))

      if action_id.present?
        action = scope.find_by(id: action_id)
        return action if key.blank? || action_matches?(action, key, version)
      end

      return if key.blank?

      scope = scope.where(key: key)
      scope = scope.where(version: version) if version.present?
      version.present? ? scope.order(id: :desc).first : Catalog::Versions.latest(scope.to_a)
    end

    def parse_action_reference(action_key, action_version)
      key, parsed_version = action_key.to_s.strip.split("@", 2)
      [ key, action_version.presence || parsed_version.presence ]
    end

    def action_matches?(action, key, version)
      action.present? && action.key == key && (version.blank? || action.version == version)
    end

    def finish_if_ready
      return if @pipeline_run.reload.status.in?(%w[waiting_for_approval waiting_for_input])

      @pipeline_run.update!(status: "completed", finished_at: Time.current)
      @pipeline_run.append_log("Pipeline completed")
      Billing::UsageRecorder.call(@pipeline_run)
      audit!("pipeline_run.completed", metadata: run_metadata.merge(step_count: @pipeline_run.action_run_steps.count))
    end

    def interaction_node?(node)
      node["type"].in?(%w[decision follow_up goal_check])
    end

    def run_interaction_node(node, index)
      existing = @pipeline_run.action_run_steps.find_by(position: index)
      if read(node, "id").to_s == @resume_node_id.to_s && existing&.status == "completed"
        existing.update!(status: "queued", output_json: {}, finished_at: nil)
      end
      return if existing&.status == "completed"

      step = existing || @pipeline_run.action_run_steps.create!(
        name: read(node, "label").presence || read(node, "question").presence || read(node, "type").to_s.humanize,
        position: index,
        input_json: @pipeline_run.input_context,
        status: "running",
        action_snapshot: node
      )
      return if step.status == "waiting_for_input"

      message = @pipeline_run.run_messages.create!(
        action_run_step: step,
        role: "assistant",
        kind: message_kind_for(node),
        status: "pending",
        content: node["question"].presence || node["prompt"].presence || "Additional input is needed before the pipeline can continue.",
        payload: interaction_payload_for(node)
      )
      step.update!(status: "waiting_for_input", output_json: { "message_id" => message.id })
      @pipeline_run.append_log("#{step.name} is waiting for input", step: step)
      @pipeline_run.update!(status: "waiting_for_input")
    end

    def message_kind_for(node)
      case read(node, "type")
      when "decision" then "choice_question"
      when "follow_up" then "open_question"
      when "goal_check" then "goal_check"
      else "text"
      end
    end

    def interaction_payload_for(node)
      {
        "node_id" => read(node, "id"),
        "choices" => Array(read(node, "choices")),
        "checks" => Array(read(node, "checks")),
        "response_schema" => read(node, "response_schema").presence || {},
        "default_choice" => read(node, "default_choice"),
        "required" => read(node, "required").nil? ? true : read(node, "required")
      }.compact
    end

    def next_index_for(node, index)
      completed_step = @pipeline_run.action_run_steps.find_by(position: index)
      @navigator.next_index_for(node, completed_step&.output_json || {}, index + 1, step_status: completed_step&.status)
    end

    def resume_index
      @navigator.node_index(@resume_node_id) if @resume_node_id.present?
    end

    def clear_resume_pointer
      return if @resume_node_id.blank?

      context = @pipeline_run.input_context.deep_dup
      context["_runner"] ||= {}
      context["_runner"].delete("resume_node_id")
      context.delete("_runner") if context["_runner"].blank?
      @pipeline_run.update!(input_context: context)
    end

    def read(value, key)
      return unless value.respond_to?(:[])

      return value[key.to_s] if value.respond_to?(:key?) && value.key?(key.to_s)
      return value[key.to_sym] if value.respond_to?(:key?) && value.key?(key.to_sym)

      value[key.to_s] || value[key.to_sym]
    end

    def audit!(action, severity: "info", metadata: {})
      Audit::Recorder.call(
        workspace: @pipeline_run.workspace,
        user: @pipeline_run.user,
        auditable: @pipeline_run,
        action: action,
        severity: severity,
        source: "runner",
        metadata: metadata
      )
    end

    def run_metadata
      {
        pipeline_run_id: @pipeline_run.id,
        pipeline_definition_id: @pipeline_run.pipeline_definition_id,
        pipeline: @pipeline_run.pipeline_definition&.name || @pipeline_run.pipeline_snapshot["name"],
        trigger: @pipeline_run.trigger,
        issue: @pipeline_run.issue&.identifier,
        project: @pipeline_run.project&.title
      }.compact
    end
  end
end

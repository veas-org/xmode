module Pipelines
  class Runner
    def self.call(pipeline_run)
      new(pipeline_run).call
    end

    def initialize(pipeline_run)
      @pipeline_run = pipeline_run
    end

    def call
      @pipeline_run.update!(status: "running", started_at: Time.current)
      @pipeline_run.append_log("Pipeline started")
      nodes.each_with_index do |node, index|
        run_node(node, index)
        break if @pipeline_run.reload.status == "waiting_for_approval"
      end
      finish_if_ready
    rescue => e
      @pipeline_run.append_log(e.message, level: "error")
      @pipeline_run.update!(status: "failed", error_message: e.message, finished_at: Time.current)
    end

    private

    def nodes
      @pipeline_run.pipeline_snapshot.fetch("graph", {}).fetch("nodes", [])
    end

    def run_node(node, index)
      existing = @pipeline_run.action_run_steps.find_by(position: index)
      return if existing&.status == "completed"

      action = @pipeline_run.workspace.action_definitions.find_by(key: node["action_key"]) ||
        @pipeline_run.workspace.action_definitions.find_by(id: node["action_id"])
      step = existing || @pipeline_run.action_run_steps.create!(
        action_definition: action,
        name: node["label"].presence || action&.name || "Action",
        position: index,
        input_json: action&.input_context_for(@pipeline_run) || @pipeline_run.input_context,
        status: "running"
      )

      if action&.provider == "manual"
        step.update!(status: "waiting_for_approval")
        @pipeline_run.approvals.create!(action_run_step: step, status: "pending")
        @pipeline_run.append_log("#{step.name} is waiting for approval", step: step)
        @pipeline_run.update!(status: "waiting_for_approval")
      elsif action&.provider == "local_shell"
        output = Runners::LocalShell.call(step)
        if output["status"] == "failed"
          step.update!(status: "failed", output_json: output, error_message: output["summary"], finished_at: Time.current)
          raise output["summary"]
        else
          step.update!(status: "completed", output_json: output, finished_at: Time.current)
        end
      else
        output = Providers::Registry.call(action.provider, step)
        step.update!(status: "completed", output_json: output, finished_at: Time.current)
      end
    end

    def finish_if_ready
      return if @pipeline_run.reload.status == "waiting_for_approval"

      @pipeline_run.update!(status: "completed", finished_at: Time.current)
      @pipeline_run.append_log("Pipeline completed")
    end
  end
end

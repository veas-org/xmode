class PipelineRunnerJob < ApplicationJob
  queue_as :default

  def perform(pipeline_run_id)
    Pipelines::Runner.call(PipelineRun.find(pipeline_run_id))
  end
end

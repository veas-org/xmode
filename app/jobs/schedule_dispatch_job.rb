class ScheduleDispatchJob < ApplicationJob
  queue_as :default

  def perform(schedule_id)
    schedule = Schedule.find(schedule_id)
    return unless schedule.status == "active"

    run = schedule.workspace.pipeline_runs.create!(
      pipeline_definition: schedule.pipeline_definition,
      trigger: schedule.kind == "recurring" ? "recurring_schedule" : "one_off_schedule",
      input_context: { schedule_id: schedule.id }
    )
    PipelineRunnerJob.perform_later(run.id)
    schedule.update!(status: "completed") if schedule.kind == "one_off"
  end
end

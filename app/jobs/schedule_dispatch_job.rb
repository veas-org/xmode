class ScheduleDispatchJob < ApplicationJob
  queue_as :default

  def perform(schedule_id)
    schedule = Schedule.find(schedule_id)
    return unless schedule.status == "active"

    project = project_for(schedule)
    issue = issue_for(schedule)
    run = schedule.workspace.pipeline_runs.create!(
      pipeline_definition: schedule.pipeline_definition,
      project: project,
      issue: issue,
      trigger: schedule.kind == "recurring" ? "recurring_schedule" : "one_off_schedule",
      input_context: {
        schedule_id: schedule.id,
        target: target_label(schedule)
      }
    )
    PipelineRunnerJob.perform_later(run.id)
    schedule.update!(status: "completed") if schedule.kind == "one_off"
  end

  private

  def project_for(schedule)
    return schedule.schedulable if schedule.schedulable.is_a?(Project)
    return schedule.schedulable.project if schedule.schedulable.is_a?(Issue)

    nil
  end

  def issue_for(schedule)
    schedule.schedulable if schedule.schedulable.is_a?(Issue)
  end

  def target_label(schedule)
    schedule.schedulable&.try(:title) || schedule.schedulable&.try(:name) || "Workspace"
  end
end

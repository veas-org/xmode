require "rails_helper"

RSpec.describe ScheduleDispatchJob, type: :job do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  it "dispatches scheduled runs with the schedule target context attached" do
    Demo::PlanetExpressSeeder.call
    workspace = Workspace.find_by!(slug: "planet-express")
    schedule = workspace.schedules.find_by!(kind: "recurring")

    expect do
      described_class.perform_now(schedule.id)
    end.to change { workspace.pipeline_runs.where(trigger: "recurring_schedule").count }.by(1)

    run = workspace.pipeline_runs.where(trigger: "recurring_schedule").last

    expect(run.pipeline_definition).to eq(schedule.pipeline_definition)
    expect(run.project).to eq(schedule.schedulable)
    expect(run.issue).to be_nil
    expect(run.input_context["schedule_id"]).to eq(schedule.id)
    expect(run.input_context["target"]).to eq(schedule.schedulable.title)
    expect(enqueued_jobs.map { |job| job.fetch(:job) }).to include(PipelineRunnerJob)
  end
end

module Billing
  class UsageRecorder
    def self.call(pipeline_run)
      new(pipeline_run).call
    end

    def initialize(pipeline_run)
      @pipeline_run = pipeline_run
    end

    def call
      return unless @pipeline_run.started_at

      @pipeline_run.with_lock do
        @pipeline_run.reload
        return if @pipeline_run.usage_recorded_at.present?

        seconds = elapsed_seconds
        minutes = (seconds / 60.0).ceil
        subscription.increment!(:automation_minutes_used, minutes)
        @pipeline_run.update!(
          automation_seconds_used: seconds,
          usage_recorded_at: Time.current
        )
        audit!(seconds, minutes)
      end
    end

    private

    def elapsed_seconds
      finished_at = @pipeline_run.finished_at || Time.current
      [ (finished_at - @pipeline_run.started_at).ceil, 1 ].max
    end

    def subscription
      @subscription ||= @pipeline_run.workspace.billing_subscriptions.order(created_at: :desc).first ||
        @pipeline_run.workspace.billing_subscriptions.create!(
          plan: @pipeline_run.workspace.billing_plan,
          status: "inactive",
          seats: @pipeline_run.workspace.memberships.count
        )
    end

    def audit!(seconds, minutes)
      Audit::Recorder.call(
        workspace: @pipeline_run.workspace,
        user: @pipeline_run.user,
        auditable: @pipeline_run,
        action: "billing.usage_recorded",
        source: "system",
        metadata: {
          pipeline_run_id: @pipeline_run.id,
          seconds: seconds,
          minutes: minutes,
          status: @pipeline_run.status
        }
      )
    end
  end
end

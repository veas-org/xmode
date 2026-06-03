class AddUsageMeteringToPipelineRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :pipeline_runs, :automation_seconds_used, :integer, null: false, default: 0
    add_column :pipeline_runs, :usage_recorded_at, :datetime
  end
end

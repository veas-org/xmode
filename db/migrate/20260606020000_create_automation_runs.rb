class CreateAutomationRuns < ActiveRecord::Migration[8.0]
  class MigrationAutomationRun < ActiveRecord::Base
    self.table_name = "automation_runs"
  end

  class MigrationPipelineRun < ActiveRecord::Base
    self.table_name = "pipeline_runs"
  end

  def up
    create_table :automation_runs do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :execution, polymorphic: true, null: false, index: false
      t.string :kind, null: false, default: "pipeline"
      t.string :status, null: false, default: "queued"
      t.string :trigger, null: false, default: "manual"
      t.string :title, null: false
      t.string :target_label
      t.text :objective
      t.json :metadata, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :automation_runs, [ :execution_type, :execution_id ], unique: true
    add_index :automation_runs, [ :workspace_id, :kind, :created_at ]
    add_index :automation_runs, [ :workspace_id, :status, :created_at ]

    backfill_pipeline_runs
  end

  def down
    drop_table :automation_runs
  end

  private

  def backfill_pipeline_runs
    MigrationPipelineRun.reset_column_information
    MigrationAutomationRun.reset_column_information

    MigrationPipelineRun.find_each do |pipeline_run|
      MigrationAutomationRun.find_or_create_by!(
        execution_type: "PipelineRun",
        execution_id: pipeline_run.id
      ) do |automation_run|
        automation_run.workspace_id = pipeline_run.workspace_id
        automation_run.kind = "pipeline"
        automation_run.status = pipeline_run.status
        automation_run.trigger = pipeline_run.trigger
        automation_run.title = "Pipeline run ##{pipeline_run.id}"
        automation_run.objective = (pipeline_run.input_context || {})["objective"]
        automation_run.started_at = pipeline_run.started_at
        automation_run.finished_at = pipeline_run.finished_at
        automation_run.created_at = pipeline_run.created_at
        automation_run.updated_at = pipeline_run.updated_at
      end
    end
  end
end

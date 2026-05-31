class RunArtifact < ApplicationRecord
  belongs_to :pipeline_run
  belongs_to :action_run_step, optional: true

  validates :name, :path, presence: true
end

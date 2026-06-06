class AgentSwarmRun < ApplicationRecord
  STATUSES = PipelineRun::STATUSES

  belongs_to :workspace
  belongs_to :agent_swarm_definition, optional: true
  belongs_to :user, optional: true
  belongs_to :project, optional: true
  belongs_to :issue, optional: true

  has_many :objectives, as: :objectiveable, dependent: :destroy
  has_many :goals, as: :goalable, dependent: :destroy
  has_one :automation_run, as: :execution, dependent: :destroy

  before_validation :capture_swarm_snapshot, on: :create
  after_create :ensure_automation_run!
  after_update :sync_automation_run!

  validates :status, inclusion: { in: STATUSES }
  validates :trigger, presence: true
  validates :swarm_snapshot, presence: true
  validate :member_results_is_a_list
  validate :swarm_snapshot_is_an_object
  validate :swarm_definition_belongs_to_workspace

  def display_status
    status.to_s.tr("_", " ").titleize
  end

  def display_trigger
    trigger.to_s.tr("_", " ").titleize
  end

  def display_title
    swarm_snapshot["name"].presence || agent_swarm_definition&.name || "Swarm run ##{id}"
  end

  def display_target
    issue&.identifier || project&.title || "Workspace"
  end

  def coordinator_snapshot
    swarm_snapshot["coordinator_agent"]
  end

  def member_snapshots
    Array(swarm_snapshot["members"])
  end

  def automation_run_attributes
    {
      workspace: workspace,
      kind: "swarm",
      status: status,
      trigger: trigger,
      title: display_title,
      target_label: display_target,
      objective: objective,
      started_at: started_at,
      finished_at: finished_at,
      metadata: {
        agent_swarm_definition_id: agent_swarm_definition_id,
        strategy: swarm_snapshot["strategy"],
        coordinator: coordinator_snapshot&.fetch("reference", nil),
        members_count: member_snapshots.size
      }.compact
    }
  end

  def ensure_automation_run!
    automation_run || create_automation_run!(automation_run_attributes)
  end

  def sync_automation_run!
    return unless automation_run

    automation_run.update!(automation_run_attributes)
  end

  private

  def capture_swarm_snapshot
    self.swarm_snapshot = agent_swarm_definition&.execution_context || swarm_snapshot.presence || {}
  end

  def swarm_definition_belongs_to_workspace
    return if agent_swarm_definition.blank? || agent_swarm_definition.workspace_id.blank? || agent_swarm_definition.workspace_id == workspace_id

    errors.add(:agent_swarm_definition, "must belong to the same workspace")
  end

  def member_results_is_a_list
    return if member_results.is_a?(Array)

    errors.add(:member_results, "must be a list")
  end

  def swarm_snapshot_is_an_object
    return if swarm_snapshot.is_a?(Hash)

    errors.add(:swarm_snapshot, "must be an object")
  end
end

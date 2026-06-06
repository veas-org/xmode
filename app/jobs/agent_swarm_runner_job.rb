class AgentSwarmRunnerJob < ApplicationJob
  queue_as :default

  def perform(agent_swarm_run_id)
    AgentSwarms::Runner.call(AgentSwarmRun.find(agent_swarm_run_id))
  end
end

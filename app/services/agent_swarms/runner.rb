module AgentSwarms
  class Runner
    def self.call(agent_swarm_run)
      new(agent_swarm_run).call
    end

    def initialize(agent_swarm_run)
      @agent_swarm_run = agent_swarm_run
    end

    def call
      @agent_swarm_run.update!(status: "running", started_at: Time.current)
      audit!("agent_swarm_run.started", metadata: run_metadata)

      member_results = member_snapshots.map.with_index do |member, index|
        agent = member["agent"].to_h
        {
          "role" => member["role"],
          "position" => member["position"] || index,
          "agent_reference" => agent["reference"],
          "agent_name" => agent["name"],
          "runtime" => agent["runtime"],
          "status" => "ready",
          "summary" => member_summary(member)
        }.compact
      end

      @agent_swarm_run.update!(
        status: "completed",
        member_results: member_results,
        result_summary: result_summary(member_results),
        finished_at: Time.current
      )
      audit!("agent_swarm_run.completed", metadata: run_metadata.merge(members_count: member_results.size))
    rescue => e
      @agent_swarm_run.update!(status: "failed", error_message: e.message, finished_at: Time.current)
      audit!("agent_swarm_run.failed", severity: "error", metadata: run_metadata.merge(error: e.message))
    end

    private

    def member_snapshots
      Array(@agent_swarm_run.swarm_snapshot["members"])
    end

    def member_summary(member)
      agent = member["agent"].to_h
      role = member["role"].presence || "member"
      instructions = member["instructions_append"].to_s.strip
      prompt = agent["system_prompt"].to_s.strip
      if instructions.present?
        "#{agent['name'] || 'Agent'} is assigned as #{role} with role-specific instructions captured."
      elsif prompt.present?
        "#{agent['name'] || 'Agent'} is assigned as #{role} with inherited system guidance captured."
      else
        "#{agent['name'] || 'Agent'} is assigned as #{role}."
      end
    end

    def result_summary(member_results)
      strategy = @agent_swarm_run.swarm_snapshot["strategy"].to_s.tr("_", " ").presence || "coordinated"
      "Prepared a #{strategy} swarm brief for #{member_results.size} #{'agent'.pluralize(member_results.size)}."
    end

    def audit!(action, severity: "info", metadata: {})
      Audit::Recorder.call(
        workspace: @agent_swarm_run.workspace,
        user: @agent_swarm_run.user,
        auditable: @agent_swarm_run,
        action: action,
        severity: severity,
        source: "runner",
        metadata: metadata
      )
    end

    def run_metadata
      {
        agent_swarm_run_id: @agent_swarm_run.id,
        agent_swarm_definition_id: @agent_swarm_run.agent_swarm_definition_id,
        status: @agent_swarm_run.status
      }
    end
  end
end

module Providers
  class CodexProvider
    def self.call(step)
      return Demo::AgentSimulator.call(step) if step.pipeline_run.workspace.demo?

      issue = step.pipeline_run.issue
      {
        "summary" => "Codex/OpenAI provider prepared context for #{issue&.identifier || "run #{step.pipeline_run_id}"}",
        "status" => "planned",
        "changed_files_count" => 0
      }
    end
  end
end

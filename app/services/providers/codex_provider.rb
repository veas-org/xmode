module Providers
  class CodexProvider
    def self.call(step)
      issue = step.pipeline_run.issue
      {
        "summary" => "Codex/OpenAI provider prepared context for #{issue&.identifier || "run #{step.pipeline_run_id}"}",
        "status" => "planned",
        "changed_files_count" => 0
      }
    end
  end
end

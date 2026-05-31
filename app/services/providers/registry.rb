module Providers
  class Registry
    def self.call(provider, step)
      case provider
      when "codex", "openai"
        CodexProvider.call(step)
      else
        { "summary" => "#{provider} provider recorded a planned action", "status" => "planned", "changed_files_count" => 0 }
      end
    end
  end
end

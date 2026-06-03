module Providers
  class Registry
    class InvalidOutput < StandardError; end

    def self.call(provider, step)
      output = case provider
      when "codex", "openai"
        CodexProvider.call(step)
      when "local_model", "ollama"
        LocalModelProvider.call(step)
      else
        { "summary" => "#{provider} provider recorded a planned action", "status" => "planned", "changed_files_count" => 0 }
      end
      validate_output!(step, output)
      output
    end

    def self.validate_output!(step, output)
      schema = JSONSchemer.schema(step.action_definition&.output_schema.presence || {})
      return if schema.valid?(output)

      errors = schema.validate(output).map do |error|
        pointer = error.fetch("data_pointer", "")
        type = error.fetch("type", "invalid")
        "#{pointer.presence || "/"} #{type}"
      end
      raise InvalidOutput, "Provider output failed schema validation: #{errors.join(", ")}"
    end
  end
end

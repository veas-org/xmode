module Catalog
  class YamlCodec
    ACTION_ATTRIBUTES = %w[key name category provider permissions input_schema output_schema defaults runtime_config timeout_seconds retry_policy artifact_policy builtin].freeze
    PIPELINE_ATTRIBUTES = %w[key name required_context graph triggers permissions builtin].freeze

    def self.dump(record)
      attributes = record.is_a?(ActionDefinition) ? ACTION_ATTRIBUTES : PIPELINE_ATTRIBUTES
      record.attributes.slice(*attributes).to_yaml
    end

    def self.load_action!(workspace, yaml)
      attrs = safe_load(yaml).slice(*ACTION_ATTRIBUTES)
      record = workspace.action_definitions.find_or_initialize_by(key: attrs.fetch("key"))
      record.assign_attributes(attrs)
      record.save!
      record
    end

    def self.load_pipeline!(workspace, yaml)
      attrs = safe_load(yaml).slice(*PIPELINE_ATTRIBUTES)
      record = workspace.pipeline_definitions.find_or_initialize_by(key: attrs.fetch("key"))
      record.assign_attributes(attrs)
      record.save!
      record
    end

    def self.safe_load(yaml)
      YAML.safe_load(yaml, permitted_classes: [ Date, Time, Symbol ], aliases: true) || {}
    end
  end
end

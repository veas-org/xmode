module Catalog
  class YamlCodec
    SKILL_ATTRIBUTES = %w[key name category description instructions objective_template plan_template input_schema output_schema best_practices metadata builtin].freeze
    ACTION_ATTRIBUTES = %w[key name category provider skill_key permissions input_schema output_schema defaults runtime_config timeout_seconds retry_policy artifact_policy requires_objective plan_required_when_objective_unclear objective_template plan_template execution_guidance best_practices builtin].freeze
    PIPELINE_ATTRIBUTES = %w[key name required_context graph triggers permissions builtin].freeze

    def self.dump(record)
      return dump_action(record) if record.is_a?(ActionDefinition)

      attributes = if record.is_a?(SkillDefinition)
        SKILL_ATTRIBUTES
      else
        PIPELINE_ATTRIBUTES
      end
      record.attributes.slice(*attributes).to_yaml
    end

    def self.load_skill!(workspace, yaml)
      attrs = safe_load(yaml).slice(*SKILL_ATTRIBUTES)
      record = workspace.skill_definitions.find_or_initialize_by(key: attrs.fetch("key"))
      record.assign_attributes(attrs)
      record.save!
      record
    end

    def self.load_action!(workspace, yaml)
      attrs = safe_load(yaml).slice(*ACTION_ATTRIBUTES)
      skill_key = attrs.delete("skill_key")
      record = workspace.action_definitions.find_or_initialize_by(key: attrs.fetch("key"))
      record.assign_attributes(attrs)
      record.skill_definition = workspace.skill_definitions.find_by(key: skill_key) if skill_key.present?
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

    def self.dump_action(record)
      attrs = record.attributes.slice(*(ACTION_ATTRIBUTES - [ "skill_key" ]))
      attrs["skill_key"] = record.skill_definition&.key
      attrs.to_yaml
    end
  end
end

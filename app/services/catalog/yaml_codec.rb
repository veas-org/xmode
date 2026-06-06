module Catalog
  class YamlCodec
    SKILL_ATTRIBUTES = %w[key name version category description instructions objective_template plan_template input_schema output_schema best_practices metadata builtin].freeze
    ACTION_ATTRIBUTES = %w[key name version category provider skill_key skill_version agent_key agent_version permissions input_schema output_schema defaults runtime_config timeout_seconds retry_policy artifact_policy requires_objective plan_required_when_objective_unclear objective_template plan_template execution_guidance best_practices builtin].freeze
    PIPELINE_ATTRIBUTES = %w[key name version required_context graph triggers permissions builtin].freeze

    def self.dump(record)
      return dump_action(record) if record.is_a?(ActionDefinition)

      attributes = if record.is_a?(SkillDefinition)
        SKILL_ATTRIBUTES
      else
        PIPELINE_ATTRIBUTES
      end
      record.attributes.slice(*attributes).to_yaml
    end

    def self.load_skill!(workspace, yaml, source: "import", user: nil)
      attrs = safe_load(yaml).slice(*SKILL_ATTRIBUTES)
      record = workspace.skill_definitions.find_or_initialize_by(
        key: attrs.fetch("key"),
        version: attrs["version"].presence || "1.0.0"
      )
      record.catalog_version_source = source
      record.catalog_version_user = user
      record.assign_attributes(attrs)
      record.save!
      record
    end

    def self.load_action!(workspace, yaml, source: "import", user: nil)
      attrs = safe_load(yaml).slice(*ACTION_ATTRIBUTES)
      skill_key = attrs.delete("skill_key")
      skill_version = attrs.delete("skill_version")
      agent_key = attrs.delete("agent_key")
      agent_version = attrs.delete("agent_version")
      record = workspace.action_definitions.find_or_initialize_by(
        key: attrs.fetch("key"),
        version: attrs["version"].presence || "1.0.0"
      )
      record.catalog_version_source = source
      record.catalog_version_user = user
      record.assign_attributes(attrs)
      record.skill_definition = find_skill(workspace, skill_key, skill_version) if skill_key.present?
      record.agent_definition = find_agent(workspace, agent_key, agent_version) if agent_key.present?
      record.save!
      record
    end

    def self.load_pipeline!(workspace, yaml, source: "import", user: nil)
      attrs = safe_load(yaml).slice(*PIPELINE_ATTRIBUTES)
      record = workspace.pipeline_definitions.find_or_initialize_by(
        key: attrs.fetch("key"),
        version: attrs["version"].presence || "1.0.0"
      )
      record.catalog_version_source = source
      record.catalog_version_user = user
      record.assign_attributes(attrs)
      record.save!
      record
    end

    def self.safe_load(yaml)
      payload = YAML.safe_load(yaml, permitted_classes: [ Date, Time, Symbol ], aliases: true) || {}
      payload.respond_to?(:deep_stringify_keys) ? payload.deep_stringify_keys : payload
    end

    def self.dump_action(record)
      attrs = record.attributes.slice(*(ACTION_ATTRIBUTES - [ "skill_key", "skill_version", "agent_key", "agent_version" ]))
      attrs["skill_key"] = record.skill_definition&.versioned_key
      attrs["agent_key"] = record.agent_definition&.versioned_key
      attrs.to_yaml
    end

    def self.find_skill(workspace, skill_reference, version = nil)
      key, parsed_version = parse_skill_reference(skill_reference)
      selected_version = version.presence || parsed_version
      scope = workspace.skill_definitions.where(key: key)
      scope = scope.where(version: selected_version) if selected_version.present?
      selected_version.present? ? scope.order(id: :desc).first : Catalog::Versions.latest(scope.to_a)
    end

    def self.parse_skill_reference(skill_reference)
      reference = skill_reference.to_s.strip
      key, version = reference.split("@", 2)
      [ key, version.presence ]
    end

    def self.find_agent(workspace, agent_reference, version = nil)
      key, parsed_version = parse_agent_reference(agent_reference)
      selected_version = version.presence || parsed_version
      scope = workspace.agent_definitions.where(key: key)
      scope = scope.where(version: selected_version) if selected_version.present?
      selected_version.present? ? scope.order(id: :desc).first : Catalog::Versions.latest(scope.to_a)
    end

    def self.parse_agent_reference(agent_reference)
      reference = agent_reference.to_s.strip
      key, version = reference.split("@", 2)
      [ key, version.presence ]
    end
  end
end

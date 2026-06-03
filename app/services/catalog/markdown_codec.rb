module Catalog
  class MarkdownCodec
    SKILL_SECTIONS = {
      "description" => "Description",
      "instructions" => "Instructions",
      "objective_template" => "Objective Template",
      "plan_template" => "Plan Template",
      "best_practices" => "Best Practices"
    }.freeze

    ACTION_SECTIONS = {
      "objective_template" => "Objective Template",
      "plan_template" => "Plan Template",
      "execution_guidance" => "Execution Guidance",
      "best_practices" => "Best Practices"
    }.freeze

    PIPELINE_SECTIONS = {
      "summary" => "Summary"
    }.freeze

    class << self
      def dump(record)
        "#{frontmatter_block(frontmatter(record))}\n\n#{body(record)}"
      end

      def frontmatter(record)
        case record
        when SkillDefinition
          skill_frontmatter(record)
        when ActionDefinition
          action_frontmatter(record)
        when PipelineDefinition
          pipeline_frontmatter(record)
        else
          raise ArgumentError, "Unsupported catalog record: #{record.class.name}"
        end
      end

      def body(record)
        case record
        when SkillDefinition
          section_document(SKILL_SECTIONS, {
            "description" => record.description,
            "instructions" => record.instructions,
            "objective_template" => record.objective_template,
            "plan_template" => record.plan_template,
            "best_practices" => bullet_list(record.best_practices)
          })
        when ActionDefinition
          section_document(ACTION_SECTIONS, {
            "objective_template" => record.objective_template,
            "plan_template" => record.plan_template,
            "execution_guidance" => record.execution_guidance,
            "best_practices" => bullet_list(record.best_practices)
          })
        when PipelineDefinition
          section_document(PIPELINE_SECTIONS, {
            "summary" => "Reusable pipeline wrapper. Runs freeze this definition, then record objectives, plans, approvals, logs, artifacts, and Change Request evidence."
          })
        else
          raise ArgumentError, "Unsupported catalog record: #{record.class.name}"
        end
      end

      def assign_skill(record, document)
        attrs, sections = parsed_attributes(document, Catalog::YamlCodec::SKILL_ATTRIBUTES)
        attrs["description"] = section_value(sections, "description", attrs["description"])
        attrs["instructions"] = section_value(sections, "instructions", attrs["instructions"])
        attrs["objective_template"] = section_value(sections, "objective_template", attrs["objective_template"])
        attrs["plan_template"] = section_value(sections, "plan_template", attrs["plan_template"])
        attrs["best_practices"] = section_list(sections, "best_practices", attrs["best_practices"])
        record.assign_attributes(attrs.except("type"))
        record
      end

      def assign_action(record, workspace, document)
        attrs, sections = parsed_attributes(document, Catalog::YamlCodec::ACTION_ATTRIBUTES)
        skill_key = attrs.delete("skill_key")
        skill_version = attrs.delete("skill_version")
        attrs["objective_template"] = section_value(sections, "objective_template", attrs["objective_template"])
        attrs["plan_template"] = section_value(sections, "plan_template", attrs["plan_template"])
        attrs["execution_guidance"] = section_value(sections, "execution_guidance", attrs["execution_guidance"])
        attrs["best_practices"] = section_list(sections, "best_practices", attrs["best_practices"])
        record.assign_attributes(attrs.except("type"))
        record.skill_definition = Catalog::YamlCodec.find_skill(workspace, skill_key, skill_version) if skill_key.present?
        record
      end

      def assign_pipeline(record, document)
        attrs, = parsed_attributes(document, Catalog::YamlCodec::PIPELINE_ATTRIBUTES)
        record.assign_attributes(attrs.except("type"))
        record
      end

      private

      def skill_frontmatter(record)
        record.attributes.slice("key", "name", "version", "category", "input_schema", "output_schema", "metadata", "builtin")
          .merge("type" => "skill")
          .sort.to_h
      end

      def action_frontmatter(record)
        record.attributes.slice(
          "key",
          "name",
          "version",
          "category",
          "provider",
          "permissions",
          "input_schema",
          "output_schema",
          "defaults",
          "runtime_config",
          "timeout_seconds",
          "retry_policy",
          "artifact_policy",
          "requires_objective",
          "plan_required_when_objective_unclear",
          "builtin"
        ).merge(
          "type" => "action",
          "skill_key" => record.skill_definition&.versioned_key
        ).compact.sort.to_h
      end

      def pipeline_frontmatter(record)
        record.attributes.slice("key", "name", "version", "required_context", "graph", "triggers", "permissions", "builtin")
          .merge("type" => "pipeline")
          .sort.to_h
      end

      def frontmatter_block(attrs)
        yaml = attrs.to_yaml.sub(/\A---\s*\n/, "").strip
        "---\n#{yaml}\n---"
      end

      def section_document(section_map, values)
        section_map.filter_map do |key, title|
          value = values[key].to_s.strip
          next if value.blank?

          "## #{title}\n\n#{value}"
        end.join("\n\n")
      end

      def parsed_attributes(document, allowed_attributes)
        metadata, body = split_document(document)
        attrs = metadata.slice(*(allowed_attributes + [ "type" ]))
        [ attrs, sections_for(body) ]
      end

      def split_document(document)
        markdown = document.to_s
        return [ {}, markdown ] unless markdown.start_with?("---\n")

        _whole, yaml, body = markdown.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)&.to_a
        raise ArgumentError, "Markdown frontmatter must be closed with ---" if yaml.blank?

        [ Catalog::YamlCodec.safe_load(yaml), body.to_s ]
      end

      def sections_for(body)
        sections = Hash.new { |hash, key| hash[key] = +"" }
        current_key = nil
        preamble = +""

        body.to_s.each_line do |line|
          if (match = line.match(/\A##\s+(.+?)\s*\z/))
            current_key = normalize_heading(match[1])
            next
          end

          if current_key
            sections[current_key] << line
          else
            preamble << line
          end
        end

        sections["description"] = preamble if preamble.strip.present? && sections["description"].blank?
        sections.transform_values { |value| value.to_s.strip }
      end

      def normalize_heading(heading)
        heading.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")
      end

      def section_value(sections, key, fallback)
        sections[key].presence || fallback
      end

      def section_list(sections, key, fallback)
        value = sections[key]
        return fallback if value.blank?

        value.lines.map do |line|
          line.strip.sub(/\A(?:[-*]|\d+\.)\s+/, "")
        end.reject(&:blank?)
      end

      def bullet_list(items)
        items.to_a.map { |item| "- #{item}" }.join("\n")
      end
    end
  end
end

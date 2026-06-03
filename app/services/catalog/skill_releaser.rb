module Catalog
  class SkillReleaser
    LEVELS = %w[major minor patch].freeze

    def self.call(skill, level:, user: nil, attributes: {})
      new(skill, level: level, user: user, attributes: attributes).call
    end

    def self.next_version(skill, level)
      new(skill, level: level).next_version
    end

    def initialize(skill, level:, user: nil, attributes: {})
      @skill = skill
      @level = level.to_s
      @user = user
      @attributes = attributes.to_h
    end

    def call
      released = skill.workspace.skill_definitions.new(released_attributes)
      released.catalog_version_source = "release"
      released.catalog_version_user = user
      released.save!
      released
    end

    def next_version
      version = bumped_version(skill.version)
      version = bumped_version(version) while version_taken?(version)
      version
    end

    private

    attr_reader :skill, :level, :user, :attributes

    def released_attributes
      skill.attributes
        .except("id", "created_at", "updated_at")
        .merge(attributes.except(:id, :key, :version, :created_at, :updated_at).stringify_keys)
        .merge("key" => skill.key, "version" => next_version)
    end

    def bumped_version(version)
      validate_level!
      major, minor, patch = version.to_s.split(/[+-]/, 2).first.split(".").map(&:to_i)

      case level
      when "major"
        [ major + 1, 0, 0 ].join(".")
      when "minor"
        [ major, minor + 1, 0 ].join(".")
      else
        [ major, minor, patch + 1 ].join(".")
      end
    end

    def version_taken?(version)
      skill.workspace.skill_definitions.exists?(key: skill.key, version: version)
    end

    def validate_level!
      return if level.in?(LEVELS)

      raise ArgumentError, "Release level must be major, minor, or patch."
    end
  end
end

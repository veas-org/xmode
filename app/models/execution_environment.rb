class ExecutionEnvironment < ApplicationRecord
  DEFAULT_NODE_DOCKER_IMAGE = "node:20-bookworm".freeze
  DEFAULT_RUBY_DOCKER_IMAGE = "ruby:3.4-bookworm".freeze
  DEFAULT_DOCKER_IMAGE = DEFAULT_NODE_DOCKER_IMAGE
  RUNNER_MODES = %w[local_worktree cloud_worker docker].freeze
  KINDS = %w[ephemeral_sandbox persistent_project_machine cloud_browser local_connector].freeze
  STATUSES = %w[ready provisioning running sleeping failed disabled].freeze

  belongs_to :workspace
  belongs_to :project, optional: true
  has_many :sandbox_sessions, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true

  def self.default_metadata_for(project = nil)
    language = language_for(project)
    {
      "runner" => "local_shell",
      "sandbox_kind" => "docker_worktree",
      "runner_mode" => "cloud_worker",
      "docker_image" => default_docker_image_for(language),
      "language" => language,
      "framework" => framework_for(project)
    }.compact
  end

  def self.language_for(project)
    text = project_signature(project)
    return "ruby" if text.match?(/\b(ruby|rails)\b/) || text.include?("hello-world-rails")
    return "typescript" if text.match?(/\b(typescript|javascript|node)\b/) || text.include?("hello-world-typescript")

    "shell"
  end

  def self.framework_for(project)
    text = project_signature(project)
    return "rails" if text.match?(/\brails\b/) || text.include?("hello-world-rails")

    nil
  end

  def self.default_docker_image_for(language)
    language.to_s == "ruby" ? DEFAULT_RUBY_DOCKER_IMAGE : DEFAULT_NODE_DOCKER_IMAGE
  end

  def runner_mode
    metadata.to_h["runner_mode"].presence_in(RUNNER_MODES) || "cloud_worker"
  end

  def docker?
    runner_mode == "docker"
  end

  def cloud_worker?
    runner_mode == "cloud_worker"
  end

  def runner_label
    case runner_mode
    when "cloud_worker" then "Cloud worker"
    when "docker" then "Docker image"
    else "Local worktree"
    end
  end

  def docker_image
    metadata.to_h["docker_image"].presence || DEFAULT_DOCKER_IMAGE
  end

  def language
    metadata.to_h["language"].presence || self.class.language_for(project)
  end

  def framework
    metadata.to_h["framework"].presence || self.class.framework_for(project)
  end

  private_class_method def self.project_signature(project)
    [
      project&.key,
      project&.title,
      project&.repository_url
    ].compact.join(" ").downcase
  end
end

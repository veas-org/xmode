class CodeModelProfile < ApplicationRecord
  PROVIDERS = %w[ollama openai anthropic].freeze
  STATUSES = %w[active disabled].freeze
  DEFAULT_MODELS = {
    "ollama" => "qwen3-coder:30b",
    "openai" => "gpt-4.1",
    "anthropic" => "claude-sonnet-4-5"
  }.freeze
  DEFAULT_BASE_URLS = {
    "ollama" => "http://xmode-ollama:11434",
    "openai" => "https://api.openai.com/v1",
    "anthropic" => "https://api.anthropic.com"
  }.freeze

  belongs_to :workspace
  has_many :admin_model_requests, dependent: :nullify

  encrypts :api_key_ciphertext
  attr_accessor :clear_api_key

  before_validation :normalize_provider
  before_validation :assign_defaults
  after_save :clear_other_defaults, if: :saved_default_profile?
  after_destroy :promote_replacement_default

  validates :name, :provider, :model, :base_url, presence: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, uniqueness: { scope: %i[workspace_id provider] }
  validates :timeout_seconds, numericality: { greater_than: 0 }
  validates :temperature, numericality: { greater_than_or_equal_to: 0 }
  validates :max_tokens, :context_window, numericality: { greater_than: 0 }

  scope :active, -> { where(status: "active") }

  def self.ensure_default_for(workspace)
    workspace.code_model_profiles.active.find_by(default_profile: true) ||
      workspace.code_model_profiles.active.order(:created_at, :id).first ||
      workspace.code_model_profiles.find_or_initialize_by(
        provider: "ollama",
        name: "Oracle Qwen"
      ).tap do |profile|
        profile.assign_attributes(
          model: ENV.fetch("LOCAL_MODEL_NAME", DEFAULT_MODELS.fetch("ollama")),
          base_url: ENV["LOCAL_MODEL_BASE_URL"].presence || ENV["OLLAMA_BASE_URL"].presence || DEFAULT_BASE_URLS.fetch("ollama"),
          timeout_seconds: ENV.fetch("LOCAL_MODEL_TIMEOUT_SECONDS", 3600).to_i,
          status: "active",
          default_profile: true,
          metadata: { "credential_mode" => "private_runtime" }
        )
        profile.save!
      end
  end

  def self.provider_options
    PROVIDERS.map { |provider| [ provider.titleize, provider ] }
  end

  def api_key
    api_key_ciphertext
  end

  def api_key=(value)
    self.api_key_ciphertext = value
  end

  def active?
    status == "active"
  end

  def byok?
    provider.in?(%w[openai anthropic])
  end

  def display_provider
    case provider
    when "ollama" then "Ollama"
    when "openai" then "OpenAI"
    when "anthropic" then "Anthropic"
    else provider.to_s.titleize
    end
  end

  def credential_label
    return "Private runtime" unless byok?
    return "BYOK saved" if api_key_ciphertext.present?
    return "ENV fallback" if environment_api_key.present?

    "BYOK required"
  end

  def endpoint_label
    URI.parse(base_url).then { |uri| "#{uri.scheme}://#{uri.host}" }
  rescue URI::InvalidURIError
    base_url
  end

  def client_options
    {
      temperature: temperature,
      max_tokens: max_tokens,
      context_window: context_window
    }.compact
  end

  def environment_api_key
    case provider
    when "openai" then ENV["OPENAI_API_KEY"].presence
    when "anthropic" then ENV["ANTHROPIC_API_KEY"].presence
    end
  end

  def resolved_api_key
    api_key_ciphertext.presence || environment_api_key
  end

  private

  def normalize_provider
    self.provider = provider.to_s.strip.downcase
    self.status = status.to_s.strip.downcase.presence || "active"
  end

  def assign_defaults
    self.name = "#{display_provider} #{model}".strip if name.blank? && provider.present?
    self.model = default_model if model.blank?
    self.base_url = default_base_url if base_url.blank?
    self.timeout_seconds = 3600 if timeout_seconds.blank? || timeout_seconds.to_i <= 0
    self.temperature = 0.2 if temperature.blank? || temperature.negative?
    self.max_tokens = 1024 if max_tokens.blank? || max_tokens.to_i <= 0
    self.context_window = 4096 if context_window.blank? || context_window.to_i <= 0
  end

  def default_base_url
    return ENV["LOCAL_MODEL_BASE_URL"].presence || ENV["OLLAMA_BASE_URL"].presence || DEFAULT_BASE_URLS.fetch("ollama") if provider == "ollama"

    DEFAULT_BASE_URLS.fetch(provider, DEFAULT_BASE_URLS.fetch("ollama"))
  end

  def default_model
    return ENV.fetch("LOCAL_MODEL_NAME", DEFAULT_MODELS.fetch("ollama")) if provider == "ollama"

    DEFAULT_MODELS.fetch(provider, DEFAULT_MODELS.fetch("ollama"))
  end

  def saved_default_profile?
    saved_change_to_default_profile? && default_profile?
  end

  def clear_other_defaults
    workspace.code_model_profiles.where.not(id: id).update_all(default_profile: false, updated_at: Time.current)
  end

  def promote_replacement_default
    return if workspace.code_model_profiles.where(default_profile: true).exists?

    workspace.code_model_profiles.active.order(:created_at, :id).first&.update!(default_profile: true)
  end
end

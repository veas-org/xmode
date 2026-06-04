class AdminModelRequest < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze

  belongs_to :workspace
  belongs_to :user

  validates :status, inclusion: { in: STATUSES }
  validates :runtime, :model, :base_url, :system_prompt, :prompt, presence: true
  validates :timeout_seconds, numericality: { greater_than: 0 }

  def queued?
    status == "queued"
  end

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def pending?
    queued? || running?
  end

  def display_status
    status.tr("_", " ").titleize
  end

  def stream_key
    [ workspace, user, :admin_qwen ]
  end

  def request_payload
    {
      model: model,
      stream: false,
      format: "json",
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: prompt }
      ],
      options: {
        temperature: 0.2,
        num_predict: 700,
        num_ctx: 4096
      }
    }
  end
end

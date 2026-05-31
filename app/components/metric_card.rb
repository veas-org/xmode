class Components::MetricCard < Components::Base
  def initialize(label:, value:, hint: nil)
    @label = label
    @value = value
    @hint = hint
  end

  def view_template
    article(class: "app-card p-4") do
      p(class: "app-eyebrow") { @label }
      p(class: "mt-2 text-2xl font-semibold text-white") { @value.to_s }
      p(class: "mt-1 text-sm text-zinc-500") { @hint } if @hint.present?
    end
  end
end

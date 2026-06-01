require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#render_markdown" do
    it "renders common markdown and filters raw html" do
      html = helper.render_markdown(<<~MARKDOWN)
        ## Objective

        - Keep **plans** visible.
        - Link [xmode](https://example.com).

        <script>alert("x")</script>
      MARKDOWN

      expect(html).to include("<h2>Objective</h2>")
      expect(html).to include("<strong>plans</strong>")
      expect(html).to include("<a href=\"https://example.com\">xmode</a>")
      expect(html).not_to include("<script>")
    end

    it "renders markdown emitted by the Tiptap round trip" do
      html = helper.render_markdown(<<~MARKDOWN)
        ## Objective

        -   Add backoff
        -   Add telemetry
      MARKDOWN

      expect(html).to include("<h2>Objective</h2>")
      expect(html).to include("<ul>")
      expect(html).to include("<li>Add backoff</li>")
      expect(html).to include("<li>Add telemetry</li>")
    end
  end
end

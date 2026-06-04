require "rails_helper"
require "webmock/rspec"

RSpec.describe Providers::CodeModelClient do
  it "normalizes an Ollama chat response" do
    stub_request(:post, "http://xmode-ollama:11434/api/chat")
      .with do |request|
        payload = JSON.parse(request.body)
        expect(payload).to include("model" => "qwen3-coder:30b", "format" => "json")
        expect(payload.dig("options", "num_ctx")).to eq(4096)
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          model: "qwen3-coder:30b",
          created_at: "2026-06-04T10:00:00Z",
          message: { content: { summary: "Ready" }.to_json }
        }.to_json
      )

    response = described_class.call(
      provider: "ollama",
      model: "qwen3-coder:30b",
      base_url: "http://xmode-ollama:11434",
      api_key: nil,
      messages: [ { role: "system", content: "Return JSON." }, { role: "user", content: "Plan." } ],
      timeout: 120,
      options: { context_window: 4096 },
      response_format: :json
    )

    expect(response).to have_attributes(
      provider: "ollama",
      model: "qwen3-coder:30b",
      content: { summary: "Ready" }.to_json,
      response_id: "2026-06-04T10:00:00Z"
    )
  end

  it "calls OpenAI Responses with a BYOK key" do
    stub_request(:post, "https://api.openai.com/v1/responses")
      .with(headers: { "Authorization" => "Bearer sk-openai" }) do |request|
        payload = JSON.parse(request.body)
        expect(payload["model"]).to eq("gpt-4.1")
        expect(payload.dig("text", "format", "type")).to eq("json_schema")
        expect(payload["input"].first["role"]).to eq("developer")
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "resp_123",
          model: "gpt-4.1",
          output_text: { summary: "OpenAI ready" }.to_json,
          usage: { input_tokens: 10, output_tokens: 4 }
        }.to_json
      )

    response = described_class.call(
      provider: "openai",
      model: "gpt-4.1",
      base_url: "https://api.openai.com/v1",
      api_key: "sk-openai",
      messages: [ { role: "system", content: "Return JSON." }, { role: "user", content: "Plan." } ],
      timeout: 120,
      options: { schema: { type: "object", additionalProperties: true }, max_tokens: 512 },
      response_format: :json
    )

    expect(response).to have_attributes(
      provider: "openai",
      model: "gpt-4.1",
      content: { summary: "OpenAI ready" }.to_json,
      response_id: "resp_123"
    )
  end

  it "calls Anthropic Messages with a BYOK key" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { "x-api-key" => "sk-ant" }) do |request|
        payload = JSON.parse(request.body)
        expect(payload["model"]).to eq("claude-sonnet-4-5")
        expect(payload["system"]).to include("Return only one JSON object")
        expect(payload["messages"].first).to include("role" => "user", "content" => "Plan.")
      end
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "msg_123",
          model: "claude-sonnet-4-5",
          content: [ { type: "text", text: { summary: "Anthropic ready" }.to_json } ],
          usage: { input_tokens: 10, output_tokens: 4 }
        }.to_json
      )

    response = described_class.call(
      provider: "anthropic",
      model: "claude-sonnet-4-5",
      base_url: "https://api.anthropic.com",
      api_key: "sk-ant",
      messages: [ { role: "system", content: "Return JSON." }, { role: "user", content: "Plan." } ],
      timeout: 120,
      options: { max_tokens: 512 },
      response_format: :json
    )

    expect(response).to have_attributes(
      provider: "anthropic",
      model: "claude-sonnet-4-5",
      content: { summary: "Anthropic ready" }.to_json,
      response_id: "msg_123"
    )
  end
end

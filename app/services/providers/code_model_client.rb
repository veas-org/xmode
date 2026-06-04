module Providers
  class CodeModelClient
    include HTTParty

    Response = Struct.new(:provider, :model, :content, :raw_response, :response_id, :usage, keyword_init: true)

    class Error < StandardError; end

    def self.call(provider:, model:, messages:, base_url:, timeout:, api_key: nil, options: {}, response_format: nil)
      new(
        provider: provider,
        model: model,
        messages: messages,
        base_url: base_url,
        timeout: timeout,
        api_key: api_key,
        options: options,
        response_format: response_format
      ).call
    end

    def self.call_profile(profile, messages:, options: {}, response_format: nil)
      call(
        provider: profile.provider,
        model: profile.model,
        base_url: profile.base_url,
        api_key: profile.resolved_api_key,
        timeout: profile.timeout_seconds,
        options: profile.client_options.merge(options.to_h.symbolize_keys),
        response_format: response_format
      )
    end

    def initialize(provider:, model:, messages:, base_url:, timeout:, api_key:, options:, response_format:)
      @provider = provider.to_s
      @model = model.to_s
      @messages = Array(messages)
      @base_url = base_url.to_s.delete_suffix("/")
      @timeout = timeout.to_i
      @api_key = api_key.to_s.presence
      @options = options.to_h.deep_symbolize_keys
      @response_format = response_format
    end

    def call
      validate_request!

      case @provider
      when "ollama", "local_model" then call_ollama
      when "openai", "codex" then call_openai
      when "anthropic", "claude" then call_anthropic
      else raise Error, "Unsupported code model provider: #{@provider}"
      end
    rescue JSON::ParserError => e
      raise Error, "Code model response was not valid JSON: #{e.message}"
    rescue HTTParty::Error, SocketError, SystemCallError, Timeout::Error => e
      raise Error, "Code model request failed: #{e.class}: #{e.message}"
    end

    private

    def validate_request!
      raise Error, "Code model provider is not configured" if @provider.blank?
      raise Error, "Code model name is not configured" if @model.blank?
      raise Error, "Code model base URL is not configured" if @base_url.blank?
      raise Error, "Code model timeout is not configured" if @timeout <= 0
      raise Error, "#{provider_label} API key is required for BYOK model profiles" if byok_provider? && @api_key.blank?
    end

    def call_ollama
      payload = {
        model: @model,
        stream: false,
        format: json_response? ? "json" : nil,
        messages: ollama_messages,
        options: ollama_options
      }.compact
      response = post_json("#{ollama_base_url}/api/chat", payload)
      content = response.dig("message", "content").presence || response["response"].to_s
      raise Error, "Ollama response did not include message content" if content.blank?

      Response.new(
        provider: "ollama",
        model: response["model"].presence || @model,
        content: content,
        raw_response: response,
        response_id: response["created_at"].presence || response["model"].presence,
        usage: response.slice("prompt_eval_count", "eval_count", "total_duration")
      )
    end

    def call_openai
      payload = {
        model: @model,
        input: openai_messages
      }
      payload[:text] = openai_text_format if json_response?
      payload[:temperature] = @options[:temperature] if @options[:temperature].present?
      payload[:max_output_tokens] = @options[:max_tokens] if @options[:max_tokens].present?

      response = post_json(
        "#{versioned_base_url("https://api.openai.com/v1")}/responses",
        payload,
        headers: { "Authorization" => "Bearer #{@api_key}" }
      )
      content = response["output_text"].presence || openai_output_text(response)
      raise Error, "OpenAI response did not include output text" if content.blank?

      Response.new(
        provider: "openai",
        model: response["model"].presence || @model,
        content: content,
        raw_response: response,
        response_id: response["id"],
        usage: response["usage"]
      )
    end

    def call_anthropic
      payload = {
        model: @model,
        system: anthropic_system_prompt,
        messages: anthropic_messages,
        max_tokens: @options[:max_tokens].presence || 1024
      }
      payload[:temperature] = @options[:temperature] if @options[:temperature].present?

      response = post_json(
        "#{versioned_base_url("https://api.anthropic.com")}/messages",
        payload.compact,
        headers: {
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01"
        }
      )
      content = Array(response["content"]).filter_map { |item| item["text"] if item["type"] == "text" }.join("\n").strip
      raise Error, "Anthropic response did not include text content" if content.blank?

      Response.new(
        provider: "anthropic",
        model: response["model"].presence || @model,
        content: content,
        raw_response: response,
        response_id: response["id"],
        usage: response["usage"]
      )
    end

    def post_json(url, payload, headers: {})
      response = self.class.post(
        url,
        headers: {
          "Content-Type" => "application/json"
        }.merge(headers),
        body: JSON.generate(payload),
        timeout: @timeout
      )
      raise Error, error_message(response) unless response.success?

      parsed = response.parsed_response
      raise Error, "#{provider_label} response was not a JSON object" unless parsed.is_a?(Hash)

      parsed
    end

    def error_message(response)
      body = response.parsed_response
      detail = if body.is_a?(Hash)
        body.dig("error", "message") || body.dig("error") || body.dig("message")
      else
        response.body
      end
      "#{provider_label} request failed with #{response.code}: #{detail}"
    rescue JSON::ParserError
      "#{provider_label} request failed with #{response.code}: #{response.body}"
    end

    def ollama_base_url
      @base_url.end_with?("/api") ? @base_url.delete_suffix("/api") : @base_url
    end

    def versioned_base_url(default)
      base = @base_url.presence || default
      return base if base.end_with?("/v1")

      "#{base}/v1"
    end

    def ollama_messages
      normalized_messages.map do |message|
        {
          role: message.fetch(:role) == "developer" ? "system" : message.fetch(:role),
          content: message.fetch(:content)
        }
      end
    end

    def openai_messages
      normalized_messages.map do |message|
        {
          role: message.fetch(:role).in?(%w[system developer]) ? "developer" : message.fetch(:role),
          content: message.fetch(:content)
        }
      end
    end

    def anthropic_system_prompt
      system_messages = normalized_messages.select { |message| message.fetch(:role).in?(%w[system developer]) }
      system = system_messages.map { |message| message.fetch(:content) }.join("\n\n")
      return system unless json_response?

      [ system, "Return only one JSON object. Do not wrap it in Markdown." ].compact_blank.join("\n\n")
    end

    def anthropic_messages
      non_system = normalized_messages.reject { |message| message.fetch(:role).in?(%w[system developer]) }
      messages = non_system.presence || [ { role: "user", content: "" } ]
      messages.map do |message|
        {
          role: message.fetch(:role) == "assistant" ? "assistant" : "user",
          content: message.fetch(:content)
        }
      end
    end

    def normalized_messages
      @normalized_messages ||= @messages.filter_map do |message|
        role = (message[:role] || message["role"]).to_s.presence || "user"
        content = (message[:content] || message["content"]).to_s
        next if content.blank?

        { role: role, content: content }
      end
    end

    def openai_text_format
      schema = @options[:schema]
      return { format: { type: "json_object" } } if schema.blank?

      {
        format: {
          type: "json_schema",
          name: "xmode_code_model_output",
          schema: schema,
          strict: false
        }
      }
    end

    def ollama_options
      {
        temperature: @options[:temperature],
        num_predict: @options[:num_predict].presence || @options[:max_tokens],
        num_ctx: @options[:num_ctx].presence || @options[:context_window]
      }.compact
    end

    def openai_output_text(response)
      Array(response["output"]).each do |item|
        Array(item["content"]).each do |content|
          return content["text"] if content["type"] == "output_text" && content["text"].present?
        end
      end
      nil
    end

    def json_response?
      @response_format.to_s == "json"
    end

    def byok_provider?
      @provider.in?(%w[openai codex anthropic claude])
    end

    def provider_label
      case @provider
      when "openai", "codex" then "OpenAI"
      when "anthropic", "claude" then "Anthropic"
      when "ollama", "local_model" then "Ollama"
      else @provider.to_s.titleize
      end
    end
  end
end

module Providers
  class LocalModelClient
    include HTTParty

    class Error < StandardError; end

    def self.call(base_url:, payload:, timeout:)
      new(base_url: base_url, payload: payload, timeout: timeout).call
    end

    def initialize(base_url:, payload:, timeout:)
      @base_url = base_url.to_s.delete_suffix("/")
      @payload = payload
      @timeout = timeout
    end

    def call
      raise Error, "Local model base URL is not configured" if @base_url.blank?

      response = self.class.post(
        "#{@base_url}/api/chat",
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(@payload),
        timeout: @timeout
      )
      raise Error, error_message(response) unless response.success?

      parsed = response.parsed_response
      raise Error, "Local model response was not a JSON object" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      raise Error, "Local model response was not valid JSON: #{e.message}"
    rescue HTTParty::Error, SocketError, SystemCallError, Timeout::Error => e
      raise Error, "Local model request failed: #{e.class}: #{e.message}"
    end

    private

    def error_message(response)
      body = response.parsed_response
      detail = body.is_a?(Hash) ? body.dig("error") || body.dig("message") : response.body
      "Local model request failed with #{response.code}: #{detail}"
    rescue JSON::ParserError
      "Local model request failed with #{response.code}: #{response.body}"
    end
  end
end

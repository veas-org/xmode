module Providers
  class OpenaiResponsesClient
    include HTTParty
    base_uri "https://api.openai.com"

    class Error < StandardError; end

    def self.call(payload:, api_key:)
      new(payload: payload, api_key: api_key).call
    end

    def initialize(payload:, api_key:)
      @payload = payload
      @api_key = api_key
    end

    def call
      response = self.class.post(
        "/v1/responses",
        headers: {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json"
        },
        body: JSON.generate(@payload)
      )
      raise Error, error_message(response) unless response.success?

      response.parsed_response
    end

    private

    def error_message(response)
      body = response.parsed_response
      detail = body.is_a?(Hash) ? body.dig("error", "message") : response.body
      "OpenAI Responses API request failed with #{response.code}: #{detail}"
    rescue JSON::ParserError
      "OpenAI Responses API request failed with #{response.code}: #{response.body}"
    end
  end
end

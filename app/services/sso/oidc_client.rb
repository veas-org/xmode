module Sso
  class OidcClient
    class Error < StandardError; end

    def initialize(provider, callback_url:)
      @provider = provider
      @callback_url = callback_url
    end

    def authorization_url(state:, nonce:)
      query = {
        client_id: @provider.client_id,
        redirect_uri: @callback_url,
        response_type: "code",
        scope: @provider.scopes.presence || "openid email profile",
        state: state,
        nonce: nonce
      }

      "#{authorization_endpoint}?#{URI.encode_www_form(query)}"
    end

    def exchange_code(code)
      response = HTTParty.post(
        token_endpoint,
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded"
        },
        body: URI.encode_www_form(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: @callback_url,
          client_id: @provider.client_id,
          client_secret: @provider.client_secret_ciphertext
        )
      )
      parsed = parse_json(response)
      raise Error, error_message("OIDC token exchange", response, parsed) unless response.success?

      parsed
    end

    def userinfo(access_token)
      raise Error, "OIDC token response did not include an access token" if access_token.blank?

      response = HTTParty.get(
        userinfo_endpoint,
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Accept" => "application/json"
        }
      )
      parsed = parse_json(response)
      raise Error, error_message("OIDC userinfo request", response, parsed) unless response.success?

      parsed
    end

    private

    def authorization_endpoint
      @provider.authorization_endpoint.presence || discovery.fetch("authorization_endpoint")
    end

    def token_endpoint
      @provider.token_endpoint.presence || discovery.fetch("token_endpoint")
    end

    def userinfo_endpoint
      @provider.userinfo_endpoint.presence || discovery.fetch("userinfo_endpoint")
    end

    def discovery
      @discovery ||= begin
        raise Error, "OIDC issuer is missing" if @provider.issuer.blank?

        response = HTTParty.get(
          "#{@provider.issuer}/.well-known/openid-configuration",
          headers: { "Accept" => "application/json" }
        )
        parsed = parse_json(response)
        raise Error, error_message("OIDC discovery", response, parsed) unless response.success?

        parsed
      end
    end

    def parse_json(response)
      JSON.parse(response.body.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def error_message(action, response, parsed)
      detail = parsed.is_a?(Hash) ? parsed["error_description"].presence || parsed["error"].presence || parsed["message"] : response.body
      "#{action} failed with #{response.code}: #{detail.presence || response.body}"
    end
  end
end

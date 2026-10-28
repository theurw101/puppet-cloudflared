# frozen_string_literal: true

require 'base64'
require 'json'
require 'net/http'
require 'uri'

module PuppetX
  module Cloudflared
    # put class in PuppetX::Cloudflared namespace to avoid collisions with other modules
    class CloudflareAPI
      API_BASE_URL = 'https://api.cloudflare.com/client/v4' # default endpoint

      # callers can rescue CloudflareAPI::Error for API problems
      class Error < StandardError; end

      # INITIALIZE CLASS VARIABLE AT OBJECT CREATION
      def initialize(api_token:, account_id:, api_base_url: API_BASE_URL, http_factory: nil)
        raise ArgumentError, 'api_token must not be empty' if api_token.to_s.empty? # reject empty api_token
        raise ArgumentError, 'account_id must be a 32-character hexadecimal ID' unless account_id.to_s.match?(%r{\A[0-9a-f]{32}\z}i) # reject invalid account_id but ignore case

        # store instance variables for use in API requests
        @api_token = api_token
        @account_id = account_id
        @api_base_url = api_base_url
        @http_factory = http_factory || method(:build_http) # if http_factory is nil or false, use build_http method
      end

      # MAIN PUBLIC METHOD
      def ensure_local_tunnel(name:, tunnel_secret:)
        validate_tunnel_secret(tunnel_secret) # validate the tunnel_secret before proceeding

        # if local tunnel exists, return it; otherwise, create a new one
        find_local_tunnel(name) || create_local_tunnel(name: name, tunnel_secret: tunnel_secret)
      end

      # FIND LOCAL TUNNEL BY NAME, IF NOT FOUND, RETURN NIL
      def find_local_tunnel(name)
        # send GET to tunnel_path with query params for name, is_deleted=false, per_page=1000
        response = request(Net::HTTP::Get, "#{tunnel_path}?#{URI.encode_www_form(name: name, is_deleted: false, per_page: 1000)}")
        # get list of tunnels
        tunnels = response.fetch('result')
        # filter for exact name matches
        matches = tunnels.select { |tunnel| tunnel['name'] == name }
        # raises error if more than one tunnel has same name
        raise Error, "Multiple Cloudflare tunnels named #{name.inspect} were found" if matches.length > 1

        tunnel = matches.first
        return unless tunnel # return nil if no matching tunnel found, which triggers creation of a new tunnel in ensure_local_tunnel
        # raise if the tunnels config_src isnt local. Tunnels configured through the dashboard can't be managed from a local config
        raise Error, "Cloudflare tunnel #{name.inspect} is not locally managed" unless tunnel['config_src'] == 'local'

        tunnel # return the matching tunnel if found and locally managed
      end

      # CREATE A NEW LOCAL TUNNEL WITH GIVEN NAME AND SECRET
      def create_local_tunnel(name:, tunnel_secret:)
        validate_tunnel_secret(tunnel_secret) # validate the tunnel_secret before proceeding
        # send POST to tunnel_path with name, config_src='local', and tunnel_secret in the body
        response = request(
          Net::HTTP::Post,
          tunnel_path,
          {
            name: name,
            config_src: 'local',
            tunnel_secret: tunnel_secret,
          },
        )
        result = response.fetch('result')
        # take result and raise if it does not include an ID, which is required for local tunnel management
        raise Error, 'Cloudflare tunnel creation response did not include an ID' if result['id'].to_s.empty?

        result # return the newly created tunnel
      end

      # private helpers for internal use only
      private

      # VALIDATE IF THE TUNNEL SECRET IS VALID
      def validate_tunnel_secret(secret)
        decoded = Base64.strict_decode64(secret.to_s) # decode secret from base64
        raise ArgumentError, 'tunnel_secret must decode to at least 32 bytes' if decoded.bytesize < 32
      rescue ArgumentError # catch both invalid base64 and too-short secrets
        # raise if the tunnel_secret is not valid base64 or is too short
        raise ArgumentError, 'tunnel_secret must be valid base64 encoding of at least 32 bytes'
      end

      # MAKE AN HTTP REQUEST TO THE CLOUDFLARE API
      def request(method, path, body = nil)
        # build the full URI by joining base URL with the path, ensuring no double slashes
        uri = URI.join("#{@api_base_url}/", path.delete_prefix('/'))
        # create connection using the http_factory, which defaults to build_http
        http = @http_factory.call(uri)
        # build HTTP request object (GET, POST, etc.) for given URI
        http_request = method.new(uri)
        # set neede headers for authorization and content type
        http_request['Authorization'] = "Bearer #{@api_token}"
        http_request['Content-Type'] = 'application/json'
        # set body if provided and convert to JSON
        http_request.body = JSON.generate(body) if body

        http_response = http.request(http_request) # send request and get response
        # raise if response is not a success (2xx)
        raise Error, "Cloudflare API returned HTTP #{http_response.code}" unless http_response.is_a?(Net::HTTPSuccess)

        # parse the response body as JSON
        envelope = JSON.parse(http_response.body)
        unless envelope['success'] # if envelope did not indicate success
          # if the API response indicates failure, extract error messages and raise with details
          messages = Array(envelope['errors']).map { |error| error['message'] }.compact
          detail = messages.empty? ? 'request failed' : messages.join('; ')
          raise Error, "Cloudflare API error: #{detail}"
        end

        envelope # return whole envelope
      rescue JSON::ParserError # if the response body is not valid JSON, raise
        raise Error, 'Cloudflare API returned invalid JSON' # handle invalid JSON response
      end

      # return tunnel collection endpoint path for the account
      def tunnel_path
        "/accounts/#{@account_id}/cfd_tunnel"
      end

      # build a new Net::HTTP object for the given URI
      def build_http(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == 'https' # enable ssl if the URI scheme is https
          http.open_timeout = 10 # so puppet puppet does not hang indefinitely if the API is unreachable
          http.read_timeout = 30 # so puppet does not hang indefinitely if the API is slow to respond
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'base64'

Puppet::Type.newtype(:cloudflared_tunnel) do # register type with Puppet as cloudflared_tunnel
  @doc = 'Create a locally managed Cloudflare Tunnel and manage its local credentials and configuration files.'

  # CONFIGURE RESOURCE PARAMETERS AND PROPERTIES

  newparam(:name) do
    desc 'The Cloudflare Tunnel name.'
    isnamevar # make it resource identifier
  end

  newparam(:account_id) do
    desc 'The Cloudflare account ID.'

    validate do |value| # validate the account_id
      raise ArgumentError, 'account_id must be a 32-character hexadecimal ID' unless value.to_s.match?(%r{\A[0-9a-f]{32}\z}i)
    end
  end

  newparam(:api_token) do # meant to be passed as a Sensitive
    desc 'A Sensitive-wrapped Cloudflare API token with tunnel write permission.'
  end

  newparam(:tunnel_secret) do # meant to be passed as a Sensitive
    desc 'A Sensitive-wrapped, base64-encoded tunnel secret of at least 32 bytes.'

    validate do |value|
      decoded_secret = Base64.strict_decode64(value.to_s)
      raise ArgumentError, 'tunnel_secret must decode to at least 32 bytes' if decoded_secret.bytesize < 32
    rescue ArgumentError # validates that the value is strict base64 that decodes to at least 32 bytes
      # same as in API class, but here we raise ArgumentError instead of CloudflareAPI::Error
      raise ArgumentError, 'tunnel_secret must be valid base64 encoding of at least 32 bytes'
    end
  end

  newparam(:credentials_file) do
    desc 'Path for the tunnel-specific credentials JSON file.'
  end

  newparam(:config_file) do
    desc 'Path for the cloudflared configuration file.'
  end

  newparam(:ingress) do
    desc 'Ingress rules for the locally managed tunnel.'
  end

  newproperty(:ensure) do
    desc 'Whether the tunnel exists and its local credentials file is valid.'

    newvalue(:present) do
      provider.create
    end

    def retrieve
      provider.exists? ? :present : :absent
    end

    defaultto :present
  end

  # adds an implicit dependency, install package before managing the tunnel resource
  autorequire(:package) do
    'cloudflared'
  end
end

# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tempfile'
require 'yaml'
require 'puppet_x/cloudflared/cloudflare_api'

Puppet::Type.type(:cloudflared_tunnel).provide(:ruby) do # REGISTER PROVIDER NAMED RUBY FOR TYPE CLOUDFLARED_TUNNEL
  desc 'Manage locally configured Cloudflare Tunnels through the Cloudflare API.'

  # IS THE TUNNEL ALREADY SET UP?
  def exists?
    tunnel = find_tunnel # look up tunnel
    return false unless tunnel # return false if no tunnel found

    # read and parse local credentials
    credentials = JSON.parse(File.read(resource[:credentials_file]))
    credentials.is_a?(Hash) &&
      credentials['TunnelID'] == tunnel['id'] && # credentials must belong to the tunnel Cloudflare reports
      credentials['AccountTag'] == resource[:account_id] && # must belong to the Cloudflare account from the manifest
      credentials['TunnelName'] == resource[:name] && # tunnel name must match
      credentials['TunnelSecret'] == unwrap(resource[:tunnel_secret]) && # secret must match the one supplied in the manifest
      File.read(resource[:config_file]) == config_content(tunnel['id'])
  rescue Errno::ENOENT, JSON::ParserError # does not exist or not valid JSON?
    false
  end

  # CREATION OF TUNNEL, CALLED WHEN exists? RETURNS FALSE
  def create
    secret = unwrap(resource[:tunnel_secret]) # make tunnel_secret plain text
    tunnel = find_tunnel # look up tunnel

    if tunnel # tunnel already exists
      ensure_existing_tunnel_secret(tunnel, secret)
    else # no tunnel exists
      # create a new tunnel through the Cloudflare API
      tunnel = cloudflare_api.create_local_tunnel(name: resource[:name], tunnel_secret: secret)
    end

    credentials = { # build creds in JSON format
      # prefer AccountTag the API returned, or fall back to the manifest
      'AccountTag' => tunnel['account_tag'] || resource[:account_id],
      # tunnel_id
      'TunnelID' => tunnel.fetch('id'),
      # tunnel name from the resource title
      'TunnelName' => resource[:name],
      # secret
      'TunnelSecret' => secret,
    }

    # write creds file
    write_file(resource[:credentials_file], "#{JSON.pretty_generate(credentials)}\n", 0o600)
    write_file(resource[:config_file], config_content(tunnel.fetch('id')), 0o644)
  end

  # private helpers for internal use only
  private

  # calls unwrap on Sensitive value, or returns the value as-is if not Sensitive
  def unwrap(value)
    value.respond_to?(:unwrap) ? value.unwrap : value
  end

  # build api client once, only if cloudflare_api doen't exist (Memoization)
  def cloudflare_api
    @cloudflare_api ||= PuppetX::Cloudflared::CloudflareAPI.new(
      api_token: unwrap(resource[:api_token]), # unwrap sensitive api_token
      account_id: resource[:account_id], # specify account ID
    )
  end

  def find_tunnel
    return @tunnel if @tunnel_looked_up # if we already looked up the tunnel, return the cached value

    @tunnel_looked_up = true # mark that tunnel has been looked up (different type of memoization)
    # look up the tunnel by name using the Cloudflare API, and cache the result in @tunnel
    @tunnel = cloudflare_api.find_local_tunnel(resource[:name])
  end

  # PROTECT AGAINST A TUNNEL WE DON'T OWN OR DIFFERENT SECRET
  def ensure_existing_tunnel_secret(tunnel, secret)
    credentials_path = resource[:credentials_file]
    # raise if cred file dos not exist, because we can't verify the tunnel_secret without it
    raise Puppet::Error, "Cloudflare tunnel #{resource[:name].inspect} already exists; supply its existing credentials file to adopt it safely" unless File.file?(credentials_path)

    # read and parse the credentials file
    credentials = JSON.parse(File.read(credentials_path))
    if credentials['TunnelID'] == tunnel['id'] && # does id match?
       credentials['TunnelSecret'] == secret && # does secret match?
       credentials['AccountTag'] == resource[:account_id] && # does account tag match?
       credentials['TunnelName'] == resource[:name] # does tunnel name match?
      return # return if all checks pass
    end

    # raise mismatch error
    raise Puppet::Error, "Credentials at #{credentials_path} do not match Cloudflare tunnel #{resource[:name].inspect} and the supplied tunnel_secret"
  rescue JSON::ParserError # give clean error if credentials file is not valid JSON
    raise Puppet::Error, "Credentials at #{credentials_path} are not valid JSON"
  end

  def config_content(tunnel_id)
    YAML.dump(
      'tunnel' => tunnel_id,
      'credentials-file' => resource[:credentials_file],
      'ingress' => resource[:ingress],
    )
  end

  # WRITE CONTENT TO FILE
  def write_file(path, content, mode)
    directory = File.dirname(path)
    FileUtils.mkdir_p(directory) # create dir
    # create temp file in same dir
    Tempfile.create(['.cloudflared-', '.tmp'], directory) do |temporary_file|
      temporary_file.write(content) # write content to temp file
      temporary_file.flush # flush to disk
      temporary_file.chmod(mode) # set permissions
      File.rename(temporary_file.path, path) # swap into place atomically
    end
  end
end

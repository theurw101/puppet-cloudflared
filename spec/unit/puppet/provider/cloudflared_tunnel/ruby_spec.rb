# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/cloudflared_tunnel'
require 'puppet/provider/cloudflared_tunnel/ruby'
require 'tmpdir'

RSpec.describe Puppet::Type.type(:cloudflared_tunnel).provider(:ruby) do
  let(:directory) { Dir.mktmpdir }
  let(:api) { instance_spy(PuppetX::Cloudflared::CloudflareAPI) }
  let(:resource) do
    Puppet::Type.type(:cloudflared_tunnel).new(
      name: 'website',
      account_id: account_id,
      api_token: 'api-token',
      tunnel_secret: secret,
      credentials_file: credentials_file,
      config_file: config_file,
      ingress: [{ 'service' => 'http://localhost:8080' }, { 'service' => 'http_status:404' }],
    )
  end

  before do
    allow(PuppetX::Cloudflared::CloudflareAPI).to receive(:new).and_return(api)
  end

  after do
    FileUtils.remove_entry(directory) if File.directory?(directory)
  end

  it 'creates a local tunnel and writes credentials' do
    tunnel = { 'id' => 'tunnel-uuid', 'account_tag' => account_id }
    allow(api).to receive(:find_local_tunnel).with('website').and_return(nil)
    allow(api).to receive(:create_local_tunnel).with(name: 'website', tunnel_secret: secret).and_return(tunnel)

    provider.create

    credentials = JSON.parse(File.read(credentials_file))
    expect(credentials).to eq(
      'AccountTag' => account_id,
      'TunnelID' => 'tunnel-uuid',
      'TunnelName' => 'website',
      'TunnelSecret' => secret,
    )
    expect(File.stat(credentials_file).mode & 0o777).to eq(0o600)
    config = YAML.safe_load(File.read(config_file))
    expect(config['tunnel']).to eq('tunnel-uuid')
    expect(config['credentials-file']).to eq(credentials_file)
    expect(config['ingress']).to eq(resource[:ingress])
  end

  it 'does not adopt an existing API tunnel without local credentials' do
    allow(api).to receive(:find_local_tunnel).with('website').and_return('id' => 'tunnel-uuid')

    expect do
      provider.create
    end.to raise_error(Puppet::Error, %r{already exists})
  end

  it 'adopts an existing tunnel when credentials match' do
    File.write(credentials_file, JSON.generate({
                                                 'AccountTag' => account_id,
                                                 'TunnelID' => 'tunnel-uuid',
                                                 'TunnelName' => 'website',
                                                 'TunnelSecret' => secret,
                                               }))
    File.write(config_file, YAML.dump(
                              'tunnel' => 'tunnel-uuid',
                              'credentials-file' => credentials_file,
                              'ingress' => resource[:ingress],
                            ))
    allow(api).to receive(:find_local_tunnel).with('website').and_return('id' => 'tunnel-uuid')

    expect { provider.create }.not_to raise_error
    expect(api).not_to have_received(:create_local_tunnel)
  end

  it 'reports drift when the tunnel is missing from Cloudflare' do
    allow(api).to receive(:find_local_tunnel).with('website').and_return(nil)

    expect(provider.exists?).to be(false)
  end

  it 'recognizes a tunnel with matching local credentials' do
    File.write(credentials_file, JSON.generate({
                                                 'AccountTag' => account_id,
                                                 'TunnelID' => 'tunnel-uuid',
                                                 'TunnelName' => 'website',
                                                 'TunnelSecret' => secret,
                                               }))
    File.write(config_file, YAML.dump(
                              'tunnel' => 'tunnel-uuid',
                              'credentials-file' => credentials_file,
                              'ingress' => resource[:ingress],
                            ))
    allow(api).to receive(:find_local_tunnel).with('website').and_return('id' => 'tunnel-uuid')

    expect(provider.exists?).to be(true)
  end

  def account_id
    '0123456789abcdef0123456789abcdef'
  end

  def credentials_file
    File.join(directory, 'website.json')
  end

  def config_file
    File.join(directory, 'config.yml')
  end

  def secret
    Base64.strict_encode64('a' * 32)
  end

  def provider
    resource.provider
  end
end

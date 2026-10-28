# frozen_string_literal: true

require 'spec_helper'

describe 'cloudflared::tunnel' do
  let(:title) { 'example-tunnel' }
  let(:pre_condition) { "service { 'cloudflared': }" }
  let(:params) do
    {
      ingress: [
        {
          'hostname' => 'app.example.com',
          'path' => '/api',
          'service' => 'http://localhost:8080',
          'originRequest' => { 'noTLSVerify' => true },
        },
        { 'service' => 'http_status:404' },
      ],
      credentials_file: '/etc/cloudflared/example.json',
      tunnel_name: 'example-tunnel-id',
    }
  end

  it { is_expected.to compile.with_all_deps }

  it 'writes the tunnel config file with the key runtime settings' do
    is_expected.to contain_file('/etc/cloudflared/config.yml').with(
      ensure: 'file',
      owner: 'root',
      group: 'root',
      mode: '0644',
    )
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{tunnel: example-tunnel-id})
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{credentials-file: /etc/cloudflared/example\.json})
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{hostname: app\.example\.com})
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{service: http://localhost:8080})
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{service: http_status:404})
    expect(catalogue.resource('File', '/etc/cloudflared/config.yml')['content']).to match(%r{noTLSVerify: true})
    is_expected.to contain_file('/etc/cloudflared/config.yml').that_notifies('Service[cloudflared]')
  end

  context 'with API-managed tunnel creation' do
    let(:pre_condition) do
      <<~PUPPET
        service { 'cloudflared': }
        cloudflared::tunnel { 'managed-example':
          ingress => [{ 'service' => 'http_status:404' }],
          credentials_file => '/etc/cloudflared/managed-example.json',
          account_id => '0123456789abcdef0123456789abcdef',
          api_token => Sensitive('api-token'),
          tunnel_secret => Sensitive('#{Base64.strict_encode64('a' * 32)}'),
        }
      PUPPET
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_cloudflared_tunnel('managed-example').with_account_id('0123456789abcdef0123456789abcdef') }
    it { is_expected.to contain_cloudflared_tunnel('managed-example').with_config_file('/etc/cloudflared/config.yml') }
    it { is_expected.to contain_cloudflared_tunnel('managed-example').with_ingress([{ 'service' => 'http_status:404' }]) }
    it { is_expected.to contain_cloudflared_tunnel('managed-example').that_notifies('Service[cloudflared]') }

    it do
      sensitive_parameters = catalogue.resource('Cloudflared_tunnel', 'managed-example').sensitive_parameters
      expect(sensitive_parameters).to contain_exactly(:api_token, :tunnel_secret)
    end
  end
end

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
      service_ensure: 'running',
      credentials_file: '/etc/cloudflared/example.json',
      tunnel_name: 'example-tunnel-id',
    }
  end

  it { is_expected.to compile.with_all_deps }

  it do
    is_expected.to contain_file('/etc/cloudflared/config.yml').with(
      ensure: 'file',
      owner: 'root',
      group: 'root',
      mode: '0644',
    ).with_content(%r{tunnel: example-tunnel-id})
  end

  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{credentials-file: /etc/cloudflared/example\.json}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{hostname: app\.example\.com}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{path: /api}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{service: http://localhost:8080}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{noTLSVerify: true}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{service: http_status:404}) }
  it { is_expected.to contain_file('/etc/cloudflared/config.yml').that_notifies('Service[cloudflared]') }
end

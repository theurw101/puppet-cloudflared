# frozen_string_literal: true

require 'spec_helper'

describe 'cloudflared' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      describe 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('cloudflared::install') }
        it { is_expected.to contain_class('cloudflared::service') }
        it { is_expected.to contain_service('cloudflared').with(ensure: 'running', enable: true) }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_archive('/tmp/cloudflared.deb').with_source(%r{cloudflared-linux-amd64\.deb$}) }
          it { is_expected.to contain_package('cloudflared').with(provider: 'dpkg', source: '/tmp/cloudflared.deb') }
        when 'RedHat', 'Suse'
          it { is_expected.to contain_archive('/tmp/cloudflared.rpm').with_source(%r{cloudflared-linux-x86_64\.rpm$}) }
          it { is_expected.to contain_package('cloudflared').with(provider: 'rpm', source: '/tmp/cloudflared.rpm') }
        end
      end

      describe 'with default parameters (no tunnel)' do
        it { is_expected.to have_cloudflared__tunnel_resource_count(0) }
      end

      context 'with tunnel parameters on the class' do
        let(:params) do
          {
            tunnel_name: '6ff42ae2-765d-4adf-8112-31c55c1551ef',
            credentials_file: '/etc/cloudflared/6ff42ae2.json',
            ingress: [
              { 'hostname' => 'app.example.com', 'service' => 'http://localhost:8080' },
              { 'service' => 'http_status:404' },
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_cloudflared__tunnel('6ff42ae2-765d-4adf-8112-31c55c1551ef').with(
            credentials_file: '/etc/cloudflared/6ff42ae2.json',
            ingress: params[:ingress],
          )
        end

        it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{^tunnel: 6ff42ae2-765d-4adf-8112-31c55c1551ef$}) }
        it { is_expected.to contain_file('/etc/cloudflared/config.yml').with_content(%r{^credentials-file: /etc/cloudflared/6ff42ae2\.json$}) }
        it { is_expected.to contain_file('/etc/cloudflared/config.yml').that_comes_before('Exec[install_cloudflared_service]') }
      end

      context 'with tunnel_name but no credentials_file' do
        let(:params) { { tunnel_name: '6ff42ae2-765d-4adf-8112-31c55c1551ef' } }

        it { is_expected.to compile.and_raise_error(%r{credentials_file is required when tunnel_name is set}) }
      end

      context 'on 64-bit ARM' do
        let(:facts) do
          arm_arch = (os_facts[:os]['family'] == 'Debian') ? 'arm64' : 'aarch64'
          os_facts.merge(os: os_facts[:os].merge('architecture' => arm_arch, 'hardware' => 'aarch64'))
        end

        it { is_expected.to compile.with_all_deps }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_archive('/tmp/cloudflared.deb').with_source(%r{cloudflared-linux-arm64\.deb$}) }
        when 'RedHat', 'Suse'
          it { is_expected.to contain_archive('/tmp/cloudflared.rpm').with_source(%r{cloudflared-linux-aarch64\.rpm$}) }
        end
      end

      context 'on an unsupported architecture' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('architecture' => 'i386', 'hardware' => 'i686')) }

        it { is_expected.to compile.and_raise_error(%r{architecture i386 is not supported}) }

        context 'when the package is absent' do
          let(:params) { { package_ensure: 'absent' } }

          it { is_expected.to compile.with_all_deps }
        end
      end

      context 'when the package is absent' do
        let(:params) { { package_ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('cloudflared').with_ensure('absent') }
        it { is_expected.to contain_exec('uninstall_cloudflared_service') }
        it { is_expected.not_to contain_archive('/tmp/cloudflared.deb') }
        it { is_expected.not_to contain_archive('/tmp/cloudflared.rpm') }
        it { is_expected.to contain_service('cloudflared').with(ensure: 'stopped', enable: false) }
      end
    end
  end
end

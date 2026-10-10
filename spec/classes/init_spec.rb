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
        it { is_expected.to contain_service('cloudflared').with(ensure: 'stopped', enable: false) }

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_archive('/tmp/cloudflared.deb').with_source(%r{cloudflared-linux-amd64\.deb$}) }
          it { is_expected.to contain_package('cloudflared').with(provider: 'dpkg', source: '/tmp/cloudflared.deb') }
        when 'RedHat', 'Suse'
          it { is_expected.to contain_archive('/tmp/cloudflared.rpm').with_source(%r{cloudflared-linux-x86_64\.rpm$}) }
          it { is_expected.to contain_package('cloudflared').with(provider: 'rpm', source: '/tmp/cloudflared.rpm') }
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

      context 'when the service should be running' do
        let(:params) { { service_ensure: 'running', service_enable: true } }

        it { is_expected.to contain_service('cloudflared').with(ensure: 'running', enable: true) }
      end
    end
  end
end

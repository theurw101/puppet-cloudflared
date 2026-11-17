# @summary Install cloudflared package
class cloudflared::install {
  $package_url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux'
  # os.architecture is amd64/arm64 on Debian and x86_64/aarch64 on RedHat/Suse
  $arch = $facts['os']['architecture'] ? {
    /^(x86_64|amd64)$/  => 'x86_64',
    /^(aarch64|arm64)$/ => 'aarch64',
    default             => undef,
  }
  if $cloudflared::package_ensure == 'present' {
    if $arch == undef {
      fail("cloudflared: architecture ${facts['os']['architecture']} is not supported (supported: x86_64/amd64, aarch64/arm64)")
    }
    case $facts['os']['family'] {
      'Debian': {
        $deb_arch = $arch ? {
          'x86_64'  => 'amd64',
          'aarch64' => 'arm64',
        }
        archive { '/tmp/cloudflared.deb':
          source => "${package_url}-${deb_arch}.deb",
        }
        package { 'cloudflared':
          ensure   => $cloudflared::package_ensure,
          provider => 'dpkg',
          source   => '/tmp/cloudflared.deb',
          require  => Archive['/tmp/cloudflared.deb'],
        }
      }
      'RedHat', 'Suse': {
        archive { '/tmp/cloudflared.rpm':
          source => "${package_url}-${arch}.rpm",
        }
        package { 'cloudflared':
          ensure   => $cloudflared::package_ensure,
          provider => 'rpm',
          source   => '/tmp/cloudflared.rpm',
          require  => Archive['/tmp/cloudflared.rpm'],
        }
      }
      default: {
        fail("${facts['os']['family']} not supported")
      }
    }
    file { '/etc/cloudflared':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => Package['cloudflared'],
    }
    exec { 'install_cloudflared_service':
      command => '/usr/bin/cloudflared service install',
      creates => '/etc/systemd/system/cloudflared.service',
      require => File['/etc/cloudflared'],
      notify  => Service['cloudflared'],
    }
  } elsif $cloudflared::package_ensure == 'absent' {
    exec { 'uninstall_cloudflared_service':
      command => '/usr/bin/cloudflared service uninstall',
      onlyif  => '/usr/bin/test -f /etc/systemd/system/cloudflared.service',
      path    => ['/usr/bin', '/bin'],
    }
    package { 'cloudflared':
      ensure  => absent,
      require => Exec['uninstall_cloudflared_service'],
    }
  }
}

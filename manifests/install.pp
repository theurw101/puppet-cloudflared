# @summary Install cloudflared package
class cloudflared::install {
  $package_url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux'
  if $cloudflared::package_ensure == 'present' {
    case $facts['os']['family'] {
      'Debian': {
        archive { '/tmp/cloudflared.deb':
          source => "${package_url}-amd64.deb",
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
          source => "${package_url}-x86_64.rpm",
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

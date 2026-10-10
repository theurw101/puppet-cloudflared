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
    }
    exec { 'install_cloudflared_service':
      command => '/usr/bin/cloudflared service install',
      creates => '/etc/systemd/system/cloudflared.service',
      path    => ['/usr/bin', '/bin'],
      returns => [0, 1], #Allows this resource to fail. It would fail to start service becasue of the not properly configured config.yaml
      require => Package['cloudflared'],
    }
    file { '/etc/cloudflared':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => Exec['install_cloudflared_service'],
    }
  } elsif $cloudflared::package_ensure == 'absent' {
    exec { 'uninstall_cloudflared_service':
      command => '/usr/bin/cloudflared service uninstall',
      onlyif  => '/usr/bin/test -f /etc/systemd/system/cloudflared.service',
      path    => ['/usr/bin', '/bin'],
    }
    case $facts['os']['family'] {
      'Debian': {
        package { 'cloudflared':
          ensure   => absent,
          provider => 'dpkg',
          require  => Exec['uninstall_cloudflared_service'],
        }
      }
      'RedHat', 'Suse': {
        package { 'cloudflared':
          ensure   => $cloudflared::package_ensure,
          provider => 'rpm',
          source   => '/tmp/cloudflared.rpm',
          require  => Archive['/tmp/cloudflared.rpm'],
        }
      }
    }
  }
}

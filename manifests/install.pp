class cloudflared::install {
  $package_file = '/tmp/cloudflared.deb'
  $package_url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb'
  if $cloudflared::package_ensure == 'present' {
    exec { 'download_cloudflared':
      command => "/usr/bin/curl -fsSL -o ${package_file} ${package_url}",
      creates => $package_file,
      path    => ['/usr/bin', '/bin'],
    }
    package { 'cloudflared':
      ensure   => $cloudflared::package_ensure,
      provider => 'dpkg',
      source   => $package_file,
      require  => Exec['download_cloudflared'],
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
    package { 'cloudflared':
      ensure   => absent,
      provider => 'dpkg',
      require  => Exec['uninstall_cloudflared_service'],
    }
  }
}

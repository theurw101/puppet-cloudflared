class cloudflared::install {
  $package_file = '/tmp/cloudflared.deb'

  $package_url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb'

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
    require => Package['cloudflared'],
  }

  file { '/etc/cloudflared':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Exec['install_cloudflared_service'],
  }
}

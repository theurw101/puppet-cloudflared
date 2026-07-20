class cloudflared::config {
  file { '/etc/cloudflared':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/cloudflared/config.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp(
      'cloudflared/config.yml.epp',
      {
        tunnel_name      => $cloudflared::tunnel_name,
        credentials_file => $cloudflared::credentials_file,
        ingress          => $cloudflared::ingress,
      },
    ),
    notify  => Service['cloudflared'],
  }
}

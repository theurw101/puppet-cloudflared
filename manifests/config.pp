class cloudflared::config {
  file { '/etc/cloudflared':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
}

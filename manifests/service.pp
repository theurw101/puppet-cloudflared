class cloudflared::service {
  service { 'cloudflared':
    ensure => $cloudflared::package_ensure ? {
      'absent' => 'stopped',
      'purged' => 'stopped',
      default  => 'stopped',
    },
    enable => $cloudflared::package_ensure ? {
      'absent' => false,
      'purged' => false,
      default  => false,
    },
  }
}

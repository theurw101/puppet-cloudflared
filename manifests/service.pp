class cloudflared::service {
  if $cloudflared::manage_service {
    service { 'cloudflared':
      ensure => $cloudflared::service_ensure,
      enable => $cloudflared::service_enable,
    }
  }
}

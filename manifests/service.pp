class cloudflared::service {
  $effective_service_ensure = $cloudflared::package_ensure ? {
    'absent'  => 'stopped',
    'present' => $cloudflared::service_ensure,
  }
  $effective_service_enable = $cloudflared::package_ensure ? {
    'absent' => false,
    default  => $cloudflared::service_enable,
  }
  service { 'cloudflared':
    ensure => $effective_service_ensure,
    enable => $effective_service_enable,
  }
}

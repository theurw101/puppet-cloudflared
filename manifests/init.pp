class cloudflared (
  String $package_ensure = 'present',
  Boolean $manage_service = true,
  Boolean $service_enable = true,
  Enum['running','stopped'] $service_ensure = 'stopped',
  Optional[String] $tunnel_name = undef,
  Optional[String] $credentials_file = undef,
  Array[Hash] $ingress = [
    {
      'service' => 'http_status:404',
    },
  ],
) {
  contain cloudflared::install
  contain cloudflared::config
  contain cloudflared::service

  Class['cloudflared::install']
  -> Class['cloudflared::config']
  ~> Class['cloudflared::service']
}

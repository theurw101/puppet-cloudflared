define cloudflared::tunnel (
  Array[Hash] $ingress,
  String $service_ensure,
  String $tunnel_name = $name,
  String $credentials_file,
) {
  file { '/etc/cloudflared/config.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cloudflared/config.yml.epp', {
        tunnel_name      => $tunnel_name,
        credentials_file => $credentials_file,
        ingress          => $ingress,
    }),
    notify  => Service['cloudflared'],
  }
}


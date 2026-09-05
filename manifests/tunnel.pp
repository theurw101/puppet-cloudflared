# @param ingress Ingress rules for the Cloudflare Tunnel
# @param service_ensure Desired state of the cloudflared service
# @param credentials_file Path to the Tunnel credentials file
# @param tunnel_name Name of the Cloudflare Tunnel
define cloudflared::tunnel (
  Array[Hash] $ingress,
  String $service_ensure,
  String $credentials_file,
  String $tunnel_name = $name,
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

# @param package_ensure Whether cloudflared should be installed
# @param manage_service Whether Puppet should manage the cloudflared service
# @param service_enable Whether the service should start at boot
# @param service_ensure Desired state of the cloudflared service
# @param tunnel_name Name of the Cloudflare Tunnel
# @param credentials_file Path to the Tunnel credentials file
# @param ingress Ingress rules for the Cloudflare Tunnel
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

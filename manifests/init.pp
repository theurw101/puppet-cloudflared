# @summary Install and manage Cloudflare Tunnel (cloudflared)
#
# A tunnel configuration is required for the service to be installed. Either
# set `tunnel_name` (and `credentials_file`) here to manage a single file-only
# tunnel, or declare a `cloudflared::tunnel` resource yourself.
#
# @param package_ensure Whether cloudflared should be installed
# @param service_enable Whether the service should start at boot
# @param service_ensure Desired state of the cloudflared service
# @param tunnel_name
#   UUID of an existing Cloudflare Tunnel. When set, the class declares a
#   file-only `cloudflared::tunnel` with `credentials_file` and `ingress`.
# @param credentials_file Path to the Tunnel credentials file; required when `tunnel_name` is set
# @param ingress Ingress rules for the tunnel declared via `tunnel_name`
class cloudflared (
  Enum['present','absent'] $package_ensure = 'present',
  Boolean $service_enable = true,
  Enum['running','stopped'] $service_ensure = 'running',
  Optional[String] $tunnel_name = undef,
  Optional[String] $credentials_file = undef,
  Array[Hash] $ingress = [
    {
      'service' => 'http_status:404',
    },
  ],
) {
  contain cloudflared::install
  contain cloudflared::service
  if $cloudflared::package_ensure == 'absent' {
    # Removal: Stop service, then uninstall package
    Class['cloudflared::service'] -> Class['cloudflared::install']
  } else {
    # Installation: Install package, then start service
    Class['cloudflared::install'] ~> Class['cloudflared::service']

    if $tunnel_name {
      if $credentials_file == undef {
        fail('cloudflared: credentials_file is required when tunnel_name is set')
      }
      cloudflared::tunnel { $tunnel_name:
        credentials_file => $credentials_file,
        ingress          => $ingress,
      }
    }

    # Every tunnel must be configured before the service is installed.
    Cloudflared::Tunnel <| |> -> Exec['install_cloudflared_service']
  }
}

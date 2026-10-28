# @param ingress Ingress rules for the Cloudflare Tunnel
# @param credentials_file Path to the Tunnel credentials file
# @param tunnel_name Name of the Cloudflare Tunnel
# @param account_id Cloudflare account ID; enables API-managed local tunnel creation when provided
# @param api_token Sensitive-wrapped Cloudflare API token with tunnel write permission
# @param tunnel_secret Sensitive-wrapped, stable base64 tunnel secret of at least 32 bytes
define cloudflared::tunnel (
  Array[Hash] $ingress,
  String $credentials_file,
  String $tunnel_name = $name,
  Optional[String] $account_id = undef,
  Optional[Sensitive[String]] $api_token = undef,
  Optional[Sensitive[String]] $tunnel_secret = undef,
) {
  $managed_parameters = [$account_id, $api_token, $tunnel_secret].filter |$value| { $value != undef }
  if length($managed_parameters) > 0 and length($managed_parameters) < 3 {
    fail('cloudflared::tunnel requires account_id, api_token, and tunnel_secret together for API-managed tunnel creation')
  }

  if $account_id == undef {
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
  } else {
    cloudflared_tunnel { $tunnel_name: #instance of custom type cloudflared_tunnel
      ensure           => present,
      account_id       => $account_id,
      api_token        => $api_token,
      tunnel_secret    => $tunnel_secret,
      credentials_file => $credentials_file,
      config_file      => '/etc/cloudflared/config.yml',
      ingress          => $ingress,
      notify           => Service['cloudflared'],
    }
  }
}

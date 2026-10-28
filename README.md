# cloudflared

[![CI](https://github.com/theurw101/puppet-cloudflared/actions/workflows/ci.yml/badge.svg)](https://github.com/theurw101/puppet-cloudflared/actions/workflows/ci.yml)
[![Release to the Puppet Forge](https://github.com/theurw101/puppet-cloudflared/actions/workflows/release.yml/badge.svg)](https://github.com/theurw101/puppet-cloudflared/actions/workflows/release.yml)
[![Puppet Forge version](https://img.shields.io/puppetforge/v/theurw101/cloudflared.svg)](https://forge.puppet.com/modules/theurw101/cloudflared)
[![Puppet Forge downloads](https://img.shields.io/puppetforge/dt/theurw101/cloudflared.svg)](https://forge.puppet.com/modules/theurw101/cloudflared)
[![Puppet >= 8.0, < 9.0](https://img.shields.io/badge/puppet-%3E%3D8.0.0_%3C_9.0.0-blue.svg)](metadata.json)
[![License: Apache-2.0](https://img.shields.io/github/license/theurw101/puppet-cloudflared.svg)](LICENSE)

Puppet module for installing and managing Cloudflare Tunnel (`cloudflared`).

## Description

This module installs and configures the Cloudflare Tunnel daemon (`cloudflared`) and manages its configuration file and system service.

The module currently supports:

* Installing `cloudflared` (Debian, RedHat, and SUSE families)
* Managing `/etc/cloudflared/config.yml`
* Managing the `cloudflared` systemd service
* API-managed creation of locally configured tunnels without a browser
* Declarative ingress configuration
* Multiple ingress rules

This module does **not** manage:

* Interactive `cloudflared tunnel login`
* Registering domains
* Creation or rotation of Cloudflare API tokens
* Public hostname DNS routes

When API-managed creation is enabled, Puppet creates a locally configured tunnel through the Cloudflare API and writes its tunnel credentials and `config.yml` on the node. The Cloudflare API token must be provisioned separately and supplied as a Puppet `Sensitive` value. Puppet checks the API during each agent run so it can recreate a tunnel that was deleted outside Puppet.

## Usage

### Example

```puppet
include cloudflared

cloudflared::tunnel { 'mytunnel':
  account_id       => '0123456789abcdef0123456789abcdef',
  api_token        => Sensitive($cloudflare_api_token),
  tunnel_secret    => Sensitive($cloudflared_tunnel_secret),
  credentials_file => '/etc/cloudflared/mytunnel.json',
  ingress => [
    {
      hostname      => 'mywebsite.example.com',
      path          => '^/api/v1/',
      service       => 'https://localhost:443',
      originRequest => {
        noTLSVerify => true,
      },
    },
    {
      service => 'http_status:404',
    },
  ],
}
```

Store the API token and tunnel secret in an encrypted Hiera backend or another secret provider. Create a Cloudflare API token with Cloudflare Tunnel read and edit permissions for the account. You can generate the tunnel secret once with `openssl rand -base64 32`, store it as a stable secret, and reuse it on every Puppet run. The API token must be available to the Puppet agent whenever it applies this resource.

Puppet will create a local tunnel without opening a browser, write a tunnel-specific credentials file with mode `0600`, and generate `/etc/cloudflared/config.yml` using the tunnel UUID returned by Cloudflare:

```yaml
tunnel: <TUNNEL-UUID>
credentials-file: /etc/cloudflared/mywebsite.json

ingress:
  - hostname: mywebsite.example.com
    path: ^/api/v1/
    service: https://localhost:443
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```

Multiple ingress rules can also by added.

The existing file-only behavior remains available when `account_id`, `api_token`, and `tunnel_secret` are omitted. Supply all three parameters to enable API-managed creation. To adopt a tunnel that already exists in Cloudflare, the credentials file must already be present at `credentials_file` and match the tunnel ID, account, name, and stable secret. The API does not allow this module to recover an existing tunnel secret, so mismatches fail rather than replacing credentials with an unusable file.

The domain's DNS zone must already be added to and active in your Cloudflare account. Puppet does not register domains or manage public hostname DNS routes. Add the required DNS record, typically a CNAME, in the **DNS → Records** section of [dash.cloudflare.com](https://dash.cloudflare.com), or create the CNAME manually with:

```sh
cloudflared tunnel route dns mytunnel <website>
```

### Uninstallation:

```puppet
class { 'cloudflared':
  package_ensure => 'absent'
}
```

## Parameters

### `cloudflared` class

| Parameter        | Type                       | Default                              |
| ---------------- | ----------------           | ------------------------------------ |
| package_ensure   | String                     | present                              |
| service_enable   | Boolean                    | true                                 |
| service_ensure   | Enum['running', 'stopped'] | running                              |
| tunnel_name      | Optional[String]           | undef                                |
| credentials_file | Optional[String]           | undef                                |
| ingress          | Array[Hash]                | `[{ service => 'http_status:404' }]` |

The cloudflared service is running and enabled at boot by default. Set `service_ensure => 'stopped'` and/or `service_enable => false` on the `cloudflared` class to override these defaults; service state is managed at the class level, not per tunnel. With API-managed tunnel creation, the tunnel resource is ordered before the service, so Puppet creates or finds the tunnel and writes its credentials JSON and config before applying the desired service state. No browser login is run; the API token authenticates tunnel creation.

### `cloudflared::tunnel` defined type

| Parameter        | Type                             | Default |
| ---------------- | -------------------------------- | ------- |
| ingress          | Array[Hash]                      | required |
| credentials_file | String                           | required |
| tunnel_name      | String                           | `$name`  |
| account_id       | Optional[String]                 | undef   |
| api_token        | Optional[Sensitive[String]]      | undef   |
| tunnel_secret    | Optional[Sensitive[String]]      | undef   |

Supply all three of `account_id`, `api_token`, and `tunnel_secret` to enable API-managed tunnel creation; wrap the token and secret with `Sensitive()`. When all three are omitted, the module keeps the file-only behavior and writes `/etc/cloudflared/config.yml` without creating or adopting a Cloudflare tunnel through the API.

## Development

Contributions are welcome.

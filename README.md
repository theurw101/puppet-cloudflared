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

* Installing `cloudflared`
* Managing `/etc/cloudflared/config.yml`
* Managing the `cloudflared` systemd service
* Declarative ingress configuration
* Multiple ingress rules
* General Cloudflare Tunnel deployments

This module does **not** currently manage:

* Interactive `cloudflared tunnel login`
* Tunnel creation
* Moving the generated credentials to the .json

Tunnel credentials must currently be created and managed externally.

## Usage

### Example

```puppet
include cloudflared

cloudflared::tunnel { 'mywebsite':
  credentials_file => '/etc/cloudflared/mywebsite.json',
  service_ensure => 'stopped',
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

This will generate `/etc/cloudflared/config.yml`:

```yaml
tunnel: mywebsite
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

### Uninstallation:

```puppet
class { 'cloudflared':
  package_ensure => 'absent'
}
```
## Manual Tunnel Setup

Cloudflare Tunnel authentication and tunnel creation currently remain external to Puppet. First run puppet, then follow cloudflares manual steps.
Then puppet can be run again with `service_ensure` set to `running`.

Example:

```bash
cloudflared tunnel login
cloudflared tunnel create mywebsite
```

Move the generated credentials file to:

```text
/etc/cloudflared/mywebsite.json
```

Then manage the configuration and service using Puppet and set `service_ensure` to `running`.

## Parameters

| Parameter        | Type                       | Default                              |
| ---------------- | ----------------           | ------------------------------------ |
| package_ensure   | String                     | present                              |
| service_enable   | Boolean                    | true                                 |
| service_ensure   | Enum['running', 'stopped'] | stopped                              |
| tunnel_name      | Optional[String]           | undef                                |
| credentials_file | Optional[String]           | undef                                |
| ingress          | Array[Hash]                | `[{ service => 'http_status:404' }]` |

## Development

Contributions are welcome.

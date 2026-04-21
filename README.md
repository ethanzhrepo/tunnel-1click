# tunnel-1click

Host-side one-click install and update scripts for an opinionated Xray REALITY setup.

This project is built for end users who want to run a single command on a Linux server and get:

- Xray downloaded from the official `XTLS/Xray-core` release
- A multi-file Xray config rendered from this repository
- A `systemd` service installed and started
- A ready-to-copy VLESS REALITY connection string printed at the end

The installer is intentionally zero-interaction on the happy path.

## What This Project Does

The repository provides two public entrypoints:

- `install.sh`
- `update.sh`

They are designed to be executed on the target server itself. The bootstrap script fetches this repository as a GitHub tarball, then runs the full host-side workflow locally.

Default behavior:

- Installs the Xray version from the repo `version` file
- Uses port `443`
- Generates a new UUID
- Generates a new REALITY private/public key pair
- Generates a new REALITY short ID
- Uses `addons.mozilla.org:443` as the default REALITY upstream target
- Uses `addons.mozilla.org` as the default REALITY server name
- Uses `chrome` as the client fingerprint
- Uses DoH resolvers:
  - `https+local://1.1.1.1/dns-query`
  - `https+local://8.8.8.8/dns-query`

Current default Xray version:

```text
v26.3.27
```

## Supported Systems

Target host requirements:

- Linux
- `systemd`
- `root` access, or `sudo` access to run the installer as root
- `bash` available on the host

Supported distro families:

- Debian
- Ubuntu
- CentOS
- RHEL

Supported CPU architectures:

- `x86_64`
- `aarch64`
- `armv7l`

## Quick Start

Install on the target host:

```sh
curl -fsSL https://raw.githubusercontent.com/ethanzhrepo/tunnel-1click/main/install.sh | sh
```

Update an existing installation:

```sh
curl -fsSL https://raw.githubusercontent.com/ethanzhrepo/tunnel-1click/main/update.sh | sh
```

If you are not root, rerun with `sudo`:

```sh
curl -fsSL https://raw.githubusercontent.com/ethanzhrepo/tunnel-1click/main/install.sh | sudo sh
```

## Install Behavior

`install.sh` performs the following steps:

1. Verifies the host is running as `root`
2. Downloads this repository snapshot from GitHub
3. Reads the target Xray version from `version`
4. Detects distro family and CPU architecture
5. Installs missing base dependencies when possible
6. Downloads the matching official Xray release asset
7. Generates:
   - UUID
   - REALITY private key
   - REALITY public key
   - REALITY short ID
8. Detects the public server IP
9. Renders Xray config templates from this repository
10. Installs Xray, config files, and a `systemd` unit
11. Validates the config before starting the service
12. Enables and starts `xray`
13. Prints connection details and the final VLESS URI

The install is designed to be zero-interaction unless the environment is missing required prerequisites or the install fails.

## Update Behavior

`update.sh` is also zero-interaction by default.

If Xray is already installed, it will:

1. Load the saved state from the previous installation
2. Re-detect the current public IP
3. Read the target version from this repository
4. Replace the Xray binary and data files if the version changed
5. Re-render the config from the latest templates in this repository
6. Preserve existing client credentials by default:
   - UUID
   - REALITY private key
   - REALITY public key
   - REALITY short ID
   - port
   - target
   - server name
7. Restart `xray`
8. Print the current connection details again

If Xray is not installed yet, `update.sh` falls back to the install flow.

## What Gets Installed

Runtime files:

- `/usr/local/bin/xray`
- `/usr/local/share/xray/geoip.dat`
- `/usr/local/share/xray/geosite.dat`
- `/usr/local/etc/xray/conf.d/*.json`
- `/etc/systemd/system/xray.service`
- `/var/log/xray/access.log`
- `/var/log/xray/error.log`

Persistent state:

- `/var/lib/tunnel-1click/install.env`
- `/var/lib/tunnel-1click/connection.txt`
- `/var/lib/tunnel-1click/rendered/`
- `/var/lib/tunnel-1click/cache/`

## Xray Configuration Layout

The project uses native Xray multi-file config loading via:

```text
/usr/local/bin/xray run -confdir /usr/local/etc/xray/conf.d
```

Installed config files:

- `10-log.json`
- `20-dns.json`
- `30-routing.json`
- `40-inbounds-reality.json`
- `50-outbounds.json`
- `60-policy.json`

The REALITY fallback is not wired as a direct public port-forward. The generated config uses a local `dokodemo-door` inbound and routing allowlist so only the configured REALITY server name is forwarded upstream; all other unauthenticated fallback traffic is blocked.

## What The Installer Prints

At the end of a successful install or update, the script prints:

- Server IP
- Port
- UUID
- Flow
- Security
- Server name
- Public key
- Short ID
- Fingerprint
- Full VLESS URI

The same content is also saved to:

```text
/var/lib/tunnel-1click/connection.txt
```

The generated URI format is:

```text
vless://UUID@SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=SERVER_NAME&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&headerType=none#xray-reality-SERVER_IP
```

## Public IP Detection

To build a usable connection string automatically, the installer detects the public IP in this order:

1. `https://ipinfo.io/json`
2. `https://api.ipify.org`
3. `https://ipv4.icanhazip.com`
4. `ip route get 1.1.1.1`

If no IP can be determined, installation stops with an error.

## Notes And Limitations

- This project is intentionally opinionated. It is not a generic Xray panel or multi-protocol installer.
- The current default REALITY upstream target is `addons.mozilla.org:443`.
- The current default REALITY server name is `addons.mozilla.org`.
- Unauthenticated REALITY fallback traffic is only allowed to the configured server name through a local `dokodemo-door` relay; other fallback traffic is blocked.
- The installer assumes a host with `systemd`.
- The bootstrap command uses `sh`, but the fetched host-side workflow uses `bash`.
- Update preserves client credentials by default. If you want a different UUID or REALITY identity, change the state or code path explicitly.
- The repository currently targets end users, not a configurable multi-tenant deployment workflow.

## Troubleshooting

### The script says I need root

Run it with `sudo`:

```sh
curl -fsSL https://raw.githubusercontent.com/ethanzhrepo/tunnel-1click/main/install.sh | sudo sh
```

### The script cannot resolve or download from GitHub

The bootstrap and installer need outbound network access to:

- `github.com`
- `raw.githubusercontent.com`

They also need access to Xray release downloads and public IP detection endpoints.

### Xray service does not start

Check:

```sh
systemctl status xray --no-pager
journalctl -u xray -n 50 --no-pager
```

Also validate the config directly:

```sh
/usr/local/bin/xray run -confdir /usr/local/etc/xray/conf.d -test
```

### I want to inspect the generated connection info later

Read:

```sh
cat /var/lib/tunnel-1click/connection.txt
```

### I want to inspect the generated config later

Read:

```sh
ls -la /usr/local/etc/xray/conf.d
cat /usr/local/etc/xray/conf.d/40-inbounds-reality.json
```

## Repository Source

Project repository:

```text
https://github.com/ethanzhrepo/tunnel-1click
```

# tunnel-1click

Host-side one-click install and update scripts for an opinionated Xray REALITY setup.

This project is built for end users who want to run a single command on a Linux server and get:

- Xray downloaded from the official `XTLS/Xray-core` release
- A multi-file Xray config rendered from this repository
- A `systemd` service installed and started
- A ready-to-copy VLESS REALITY connection string printed at the end

The installer is intentionally low-interaction on the happy path.

## What This Project Does

The repository provides two public entrypoints:

- `install.sh`
- `update.sh`

They are designed to be executed on the target server itself. The bootstrap script fetches this repository as a GitHub tarball, then runs the full host-side workflow locally.

Repository-controlled config files:

- `version`: target Xray release
- `reality-targets`: default REALITY upstream target candidates in `host:port` form
- `connect-address`: default client-facing address printed in the final URI

Helper scripts:

- `scripts/check.sh`: validate one REALITY target candidate
- `scripts/probe.sh`: rank repository candidates and print the best target

Default behavior:

- Installs the Xray version from the repo `version` file
- Uses port `443`
- Generates a new UUID
- Generates a new REALITY private/public key pair
- Generates a new REALITY short ID
- Uses the best currently available target from `reality-targets` during install
- Reuses the saved REALITY target during update when it still passes validation
- Uses `chrome` as the client fingerprint
- Uses DoH resolvers:
  - `https+local://1.1.1.1/dns-query`
  - `https+local://8.8.8.8/dns-query`

Persistent host config files:

- `/var/lib/tunnel-1click/reality-targets`
- `/var/lib/tunnel-1click/connect-address`

The installer uses the Xray version pinned in the repository `version` file.

The repository also includes a weekly GitHub Actions workflow that checks the latest `XTLS/Xray-core` release and opens or updates a pull request when `version` changes.

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
9. Initializes `/var/lib/tunnel-1click/reality-targets` when it is missing:
   - prompts for a custom REALITY target when a TTY is available
   - uses `addons.mozilla.org:443` when you press Enter
10. Initializes `/var/lib/tunnel-1click/connect-address` when it is missing:
   - prompts for a custom domain or IP when a TTY is available
   - leaves it empty when you press Enter so clients use the detected public IP
11. Runs `scripts/probe.sh` against the saved `reality-targets`
12. Selects the best candidate as `REALITY_TARGET` and derives `REALITY_SERVER_NAME`
13. Reads `connect-address` and validates it against the current server IP when configured
14. Renders Xray config templates from this repository
15. Installs Xray, config files, and a `systemd` unit
16. Validates the config before starting the service
17. Enables and starts `xray`
18. Prints connection details and the final VLESS URI

The install is designed to use saved host config when present. On the first install it prompts only to seed `reality-targets` and `connect-address`; if no TTY is available it falls back to the default target and detected public IP automatically.

## Update Behavior

`update.sh` is also zero-interaction by default.

If Xray is already installed, it will:

1. Load the saved state from the previous installation
2. Re-detect the current public IP
3. Read the target version from this repository
4. Replace the Xray binary and data files if the version changed
5. Validate the saved REALITY target with `scripts/check.sh`
6. If the saved target fails, scan the saved `reality-targets` top-to-bottom and switch to the first valid candidate
7. Re-read the saved `connect-address` and validate it when configured
8. Re-render the config from the latest templates in this repository
9. Preserve existing client credentials by default:
   - UUID
   - REALITY private key
   - REALITY public key
   - REALITY short ID
   - port
10. Restart `xray`
11. Print the current connection details again

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
- `/var/lib/tunnel-1click/reality-targets`
- `/var/lib/tunnel-1click/connect-address`
- `/var/lib/tunnel-1click/rendered/`
- `/var/lib/tunnel-1click/cache/`

Saved state includes:

- `REALITY_TARGET`
- `REALITY_SERVER_NAME`
- `CONNECT_ADDRESS`
- `CONNECT_ADDRESS_SOURCE`

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

## Target Selection

`/var/lib/tunnel-1click/reality-targets` contains the pool of upstream camouflage targets used by install and update.

Example:

```text
addons.mozilla.org:443
www.apple.com:443
www.cloudflare.com:443
```

Install behavior:

- the first install seeds the file from your prompt or the default `addons.mozilla.org:443`
- `scripts/probe.sh` checks all saved candidates
- the best valid candidate becomes `REALITY_TARGET`
- `REALITY_SERVER_NAME` defaults to the target host

Update behavior:

- validates the saved target first
- only switches targets when the saved one fails validation
- falls back to the first valid saved candidate

You can also run the helper scripts manually:

```sh
bash scripts/check.sh addons.mozilla.org:443
bash scripts/probe.sh
```

## Connect Address

`/var/lib/tunnel-1click/connect-address` is optional and only affects what address is printed to the client.

Examples:

```text
edge.example.com
```

or:

```text
203.0.113.10
```

If the file is absent, empty, or commented out, the generated URI uses the detected public IP.

In the current REALITY mode, `connect-address` does not:

- change `REALITY_TARGET`
- change `REALITY_SERVER_NAME`
- require `acme.sh`
- require a server-managed TLS certificate just because clients connect by domain instead of IP

## What The Installer Prints

At the end of a successful install or update, the script prints:

- Server address
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
vless://UUID@SERVER_ADDRESS:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=SERVER_NAME&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&headerType=none#xray-reality-SERVER_ADDRESS
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
- The repository default target pool currently starts with `addons.mozilla.org:443`.
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

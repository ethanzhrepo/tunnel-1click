#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/repo.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/targets.sh"
source "$SCRIPT_DIR/lib/xray.sh"
source "$SCRIPT_DIR/lib/render.sh"
source "$SCRIPT_DIR/lib/runtime.sh"

t1c_install_ensure_dependencies() {
  local distro_family
  local missing=()

  if [[ "${T1C_SKIP_DEPENDENCY_INSTALL:-0}" == "1" ]]; then
    return 0
  fi

  for cmd in curl tar gzip unzip sed awk grep mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ "${T1C_SKIP_SYSTEMD:-0}" != "1" ]] && ! command -v systemctl >/dev/null 2>&1; then
    t1c_die 'systemctl is required on the target host'
  fi

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi

  distro_family="$(t1c_detect_distro_family_from_file /etc/os-release)"
  case "$distro_family" in
    debian)
      apt-get update
      apt-get install -y curl tar gzip unzip ca-certificates iproute2
      ;;
    rhel)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl tar gzip unzip ca-certificates iproute
      else
        yum install -y curl tar gzip unzip ca-certificates iproute
      fi
      ;;
    *)
      t1c_die 'unsupported distro family'
      ;;
  esac
}

t1c_install_main() {
  local snapshot_dir package_dir render_dir version arch uuid keypair private_key public_key short_id server_ip probe_output repo_connect_address resolved_connect_address connect_address_source

  t1c_require_root
  t1c_install_ensure_dependencies

  snapshot_dir="${T1C_SNAPSHOT_DIR:-}"
  if [[ -z "$snapshot_dir" ]]; then
    snapshot_dir="$(t1c_fetch_repo_snapshot "$(mktemp -d "${TMPDIR:-/tmp}/t1c-snapshot.XXXXXX")")"
  fi

  version="$(t1c_read_version_file "$snapshot_dir/version")"
  arch="$(t1c_detect_arch)"

  package_dir="${T1C_XRAY_PACKAGE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/t1c-package.XXXXXX")}"
  if [[ -z "${T1C_XRAY_PACKAGE_DIR:-}" ]]; then
    t1c_download_xray_release "$version" "$arch" "$package_dir"
  fi

  uuid="$(t1c_generate_uuid "$package_dir/xray")"
  keypair="$(t1c_generate_reality_keypair "$package_dir/xray")"
  private_key="${keypair%%,*}"
  public_key="${keypair##*,}"
  short_id="$(t1c_generate_short_id)"
  server_ip="$(t1c_detect_public_ip)"

  export XRAY_VERSION="$version"
  export XRAY_PORT="443"
  export SERVER_IP="$server_ip"
  export UUID="$uuid"
  export REALITY_PRIVATE_KEY="$private_key"
  export REALITY_PUBLIC_KEY="$public_key"
  export REALITY_SHORT_ID="$short_id"
  probe_output="$(bash "$SCRIPT_DIR/probe.sh" "$snapshot_dir/reality-targets")"
  export REALITY_TARGET="$(awk -F= '/^BEST_TARGET=/{print $2}' <<<"$probe_output")"
  [[ -n "$REALITY_TARGET" ]] || t1c_die 'no valid REALITY target candidates'
  export REALITY_SERVER_NAME="$(t1c_target_host "$REALITY_TARGET")"
  export TLS_FINGERPRINT="chrome"
  repo_connect_address="$(t1c_read_connect_address "$snapshot_dir/connect-address")"
  if [[ -n "$repo_connect_address" ]]; then
    t1c_validate_connect_address "$repo_connect_address" "$server_ip" || t1c_die 'connect-address does not resolve to this server'
    resolved_connect_address="$repo_connect_address"
    connect_address_source="config"
  else
    resolved_connect_address="$server_ip"
    connect_address_source="ip"
  fi
  export CONNECT_ADDRESS="$resolved_connect_address"
  export CONNECT_ADDRESS_SOURCE="$connect_address_source"

  render_dir="$(mktemp -d "${TMPDIR:-/tmp}/t1c-render.XXXXXX")"
  t1c_render_snapshot "$snapshot_dir" "$render_dir"
  t1c_prepare_runtime_dirs
  t1c_install_runtime_files "$package_dir" "$render_dir"

  t1c_write_state_file "$(t1c_state_file)" \
    "XRAY_VERSION=$XRAY_VERSION" \
    "XRAY_PORT=$XRAY_PORT" \
    "SERVER_IP=$SERVER_IP" \
    "UUID=$UUID" \
    "REALITY_PRIVATE_KEY=$REALITY_PRIVATE_KEY" \
    "REALITY_PUBLIC_KEY=$REALITY_PUBLIC_KEY" \
    "REALITY_SHORT_ID=$REALITY_SHORT_ID" \
    "REALITY_TARGET=$REALITY_TARGET" \
    "REALITY_SERVER_NAME=$REALITY_SERVER_NAME" \
    "TLS_FINGERPRINT=$TLS_FINGERPRINT" \
    "CONNECT_ADDRESS=$CONNECT_ADDRESS" \
    "CONNECT_ADDRESS_SOURCE=$CONNECT_ADDRESS_SOURCE"

  t1c_validate_config
  t1c_enable_and_start_service || {
    t1c_show_service_failures
    return 1
  }

  cat "$(t1c_connection_file)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  t1c_install_main "$@"
fi

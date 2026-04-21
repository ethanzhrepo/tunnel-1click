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

t1c_update_main() {
  local snapshot_dir package_dir render_dir desired_version current_version current_arch server_ip

  t1c_require_root

  snapshot_dir="${T1C_SNAPSHOT_DIR:-}"
  if [[ -z "$snapshot_dir" ]]; then
    snapshot_dir="$(t1c_fetch_repo_snapshot "$(mktemp -d "${TMPDIR:-/tmp}/t1c-snapshot.XXXXXX")")"
  fi

  if [[ ! -f "$(t1c_state_file)" ]]; then
    exec bash "$SCRIPT_DIR/host-install.sh"
  fi

  t1c_load_state_file "$(t1c_state_file)"
  server_ip="$(t1c_detect_public_ip)"
  desired_version="$(t1c_read_version_file "$snapshot_dir/version")"
  current_version="$("$(t1c_bin_dir)/xray" version | awk 'NR==1 {print $2}')"
  current_arch="$(t1c_detect_arch)"

  package_dir="${T1C_XRAY_PACKAGE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/t1c-package.XXXXXX")}"
  if [[ "$current_version" != "$desired_version" ]]; then
    if [[ -z "${T1C_XRAY_PACKAGE_DIR:-}" ]]; then
      t1c_download_xray_release "$desired_version" "$current_arch" "$package_dir"
    fi
    install -m 0755 "$package_dir/xray" "$(t1c_bin_dir)/xray"
    install -m 0644 "$package_dir/geoip.dat" "$(t1c_share_dir)/geoip.dat"
    install -m 0644 "$package_dir/geosite.dat" "$(t1c_share_dir)/geosite.dat"
    XRAY_VERSION="$desired_version"
  fi

  SERVER_IP="$server_ip"
  export XRAY_VERSION XRAY_PORT SERVER_IP UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID REALITY_TARGET REALITY_SERVER_NAME TLS_FINGERPRINT

  render_dir="$(mktemp -d "${TMPDIR:-/tmp}/t1c-render.XXXXXX")"
  t1c_render_snapshot "$snapshot_dir" "$render_dir"
  t1c_prepare_runtime_dirs
  install -m 0644 "$render_dir/server/"*.json "$(t1c_conf_dir)/"
  install -m 0644 "$render_dir/xray.service" "$(t1c_systemd_dir)/xray.service"
  install -m 0644 "$render_dir/connection.txt" "$(t1c_connection_file)"
  cp -R "$render_dir/." "$(t1c_rendered_dir)/"

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
    "TLS_FINGERPRINT=$TLS_FINGERPRINT"

  t1c_validate_config
  t1c_restart_service || {
    t1c_show_service_failures
    return 1
  }

  cat "$(t1c_connection_file)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  t1c_update_main "$@"
fi

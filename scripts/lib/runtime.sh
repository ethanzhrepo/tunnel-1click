#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state.sh"

t1c_prepare_runtime_dirs() {
  mkdir -p \
    "$(t1c_bin_dir)" \
    "$(t1c_share_dir)" \
    "$(t1c_conf_dir)" \
    "$(t1c_systemd_dir)" \
    "$(t1c_log_dir)" \
    "$(t1c_state_dir)" \
    "$(t1c_rendered_dir)" \
    "$(t1c_cache_dir)"
}

t1c_install_runtime_files() {
  local package_dir="$1"
  local render_dir="$2"

  install -m 0755 "$package_dir/xray" "$(t1c_bin_dir)/xray"
  install -m 0644 "$package_dir/geoip.dat" "$(t1c_share_dir)/geoip.dat"
  install -m 0644 "$package_dir/geosite.dat" "$(t1c_share_dir)/geosite.dat"
  install -m 0644 "$render_dir/server/"*.json "$(t1c_conf_dir)/"
  install -m 0644 "$render_dir/xray.service" "$(t1c_systemd_dir)/xray.service"
  install -m 0644 "$render_dir/connection.txt" "$(t1c_connection_file)"
  cp -R "$render_dir/." "$(t1c_rendered_dir)/"
}

t1c_validate_config() {
  "$(t1c_bin_dir)/xray" run -confdir "$(t1c_conf_dir)" -test
}

t1c_systemctl() {
  if [[ "${T1C_SKIP_SYSTEMD:-0}" == "1" ]]; then
    return 0
  fi
  systemctl "$@"
}

t1c_enable_and_start_service() {
  t1c_systemctl daemon-reload
  t1c_systemctl enable --now xray
  t1c_systemctl is-active xray
}

t1c_restart_service() {
  t1c_systemctl daemon-reload
  t1c_systemctl restart xray
  t1c_systemctl is-active xray
}

t1c_show_service_failures() {
  if [[ "${T1C_SKIP_SYSTEMD:-0}" == "1" ]]; then
    return 0
  fi

  systemctl status xray --no-pager || true
  journalctl -u xray -n 30 --no-pager || true
}

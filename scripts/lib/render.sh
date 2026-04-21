#!/usr/bin/env bash
set -euo pipefail

t1c_escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

t1c_render_one() {
  local template_file="$1"
  local output_file="$2"

  mkdir -p "$(dirname "$output_file")"
  sed \
    -e "s|__XRAY_VERSION__|$(t1c_escape_sed_replacement "${XRAY_VERSION}")|g" \
    -e "s|__XRAY_PORT__|$(t1c_escape_sed_replacement "${XRAY_PORT}")|g" \
    -e "s|__SERVER_IP__|$(t1c_escape_sed_replacement "${SERVER_IP}")|g" \
    -e "s|__UUID__|$(t1c_escape_sed_replacement "${UUID}")|g" \
    -e "s|__REALITY_PRIVATE_KEY__|$(t1c_escape_sed_replacement "${REALITY_PRIVATE_KEY}")|g" \
    -e "s|__REALITY_PUBLIC_KEY__|$(t1c_escape_sed_replacement "${REALITY_PUBLIC_KEY}")|g" \
    -e "s|__REALITY_SHORT_ID__|$(t1c_escape_sed_replacement "${REALITY_SHORT_ID}")|g" \
    -e "s|__REALITY_TARGET__|$(t1c_escape_sed_replacement "${REALITY_TARGET}")|g" \
    -e "s|__REALITY_SERVER_NAME__|$(t1c_escape_sed_replacement "${REALITY_SERVER_NAME}")|g" \
    -e "s|__TLS_FINGERPRINT__|$(t1c_escape_sed_replacement "${TLS_FINGERPRINT}")|g" \
    "$template_file" >"$output_file"
}

t1c_render_snapshot() {
  local snapshot_dir="$1"
  local output_dir="$2"
  local template_root="$snapshot_dir/templates"

  mkdir -p "$output_dir/server"
  t1c_render_one "$template_root/server/10-log.json.tpl" "$output_dir/server/10-log.json"
  t1c_render_one "$template_root/server/20-dns.json.tpl" "$output_dir/server/20-dns.json"
  t1c_render_one "$template_root/server/30-routing.json.tpl" "$output_dir/server/30-routing.json"
  t1c_render_one "$template_root/server/40-inbounds-reality.json.tpl" "$output_dir/server/40-inbounds-reality.json"
  t1c_render_one "$template_root/server/50-outbounds.json.tpl" "$output_dir/server/50-outbounds.json"
  t1c_render_one "$template_root/server/60-policy.json.tpl" "$output_dir/server/60-policy.json"
  t1c_render_one "$template_root/systemd/xray.service.tpl" "$output_dir/xray.service"
  t1c_render_one "$template_root/client/connection.txt.tpl" "$output_dir/connection.txt"
}

#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

t1c_xray_asset_name() {
  local normalized_arch="$1"

  case "$normalized_arch" in
    x86_64)
      printf 'Xray-linux-64.zip\n'
      ;;
    aarch64)
      printf 'Xray-linux-arm64-v8a.zip\n'
      ;;
    armv7l)
      printf 'Xray-linux-arm32-v7a.zip\n'
      ;;
    *)
      t1c_die "unsupported architecture: $normalized_arch"
      ;;
  esac
}

t1c_xray_release_url() {
  local version="$1"
  local normalized_arch="$2"

  printf 'https://github.com/XTLS/Xray-core/releases/download/%s/%s\n' \
    "$version" \
    "$(t1c_xray_asset_name "$normalized_arch")"
}

t1c_download_xray_release() {
  local version="$1"
  local normalized_arch="$2"
  local output_dir="$3"
  local archive_path

  mkdir -p "$output_dir"
  archive_path="$output_dir/xray.zip"

  curl -fsSL "$(t1c_xray_release_url "$version" "$normalized_arch")" -o "$archive_path"
  unzip -o "$archive_path" -d "$output_dir" >/dev/null
}

t1c_extract_private_key() {
  awk -F': ' '/^Private key:/ {print $2; exit}'
}

t1c_extract_public_key() {
  awk -F': ' '/^Public key:/ {print $2; exit}'
}

t1c_generate_uuid() {
  local xray_bin="$1"
  "$xray_bin" uuid | tr -d '\r\n'
}

t1c_generate_reality_keypair() {
  local xray_bin="$1"
  local output private_key public_key

  output="$("$xray_bin" x25519)"
  private_key="$(printf '%s\n' "$output" | t1c_extract_private_key)"
  public_key="$(printf '%s\n' "$output" | t1c_extract_public_key)"
  printf '%s,%s\n' "$private_key" "$public_key"
}

t1c_generate_short_id() {
  od -An -N8 -tx1 /dev/urandom | tr -d ' \n'
}

t1c_extract_ipinfo_ip() {
  awk -F'"' '/"ip"[[:space:]]*:/ {print $4; exit}'
}

t1c_detect_public_ip() {
  local detected_ip=""

  if [[ -n "${T1C_PUBLIC_IP:-}" ]]; then
    printf '%s\n' "$T1C_PUBLIC_IP"
    return 0
  fi

  detected_ip="$(curl -fsSL https://ipinfo.io/json | t1c_extract_ipinfo_ip || true)"
  [[ -n "$detected_ip" ]] && { printf '%s\n' "$detected_ip"; return 0; }

  detected_ip="$(curl -fsSL https://api.ipify.org || true)"
  [[ -n "$detected_ip" ]] && { printf '%s\n' "$detected_ip"; return 0; }

  detected_ip="$(curl -fsSL https://ipv4.icanhazip.com 2>/dev/null | tr -d '\r\n' || true)"
  [[ -n "$detected_ip" ]] && { printf '%s\n' "$detected_ip"; return 0; }

  detected_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}' || true)"
  [[ -n "$detected_ip" ]] && { printf '%s\n' "$detected_ip"; return 0; }

  t1c_die 'unable to determine public server IP'
}

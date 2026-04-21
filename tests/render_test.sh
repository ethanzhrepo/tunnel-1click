#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/render.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local output_dir snapshot_dir

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT
  output_dir="$TMPDIR_FOR_TEST/rendered"
  snapshot_dir="$ROOT_DIR"

  export XRAY_VERSION="v26.3.27"
  export XRAY_PORT="443"
  export SERVER_IP="203.0.113.10"
  export CONNECT_ADDRESS="edge.example.com"
  export UUID="11111111-1111-1111-1111-111111111111"
  export REALITY_PRIVATE_KEY="private-key"
  export REALITY_PUBLIC_KEY="public-key"
  export REALITY_SHORT_ID="0123456789abcdef"
  export REALITY_TARGET="addons.mozilla.org:443"
  export REALITY_SERVER_NAME="addons.mozilla.org"
  export REALITY_FALLBACK_PORT="4431"
  export TLS_FINGERPRINT="chrome"

  t1c_render_snapshot "$snapshot_dir" "$output_dir"

  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"tag":[[:space:]]*"dokodemo-in"'
  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"address":[[:space:]]*"addons.mozilla.org"'
  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"port":[[:space:]]*443'
  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"target":[[:space:]]*"127.0.0.1:4431"'
  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"id":[[:space:]]*"11111111-1111-1111-1111-111111111111"'
  assert_match "$(cat "$output_dir/server/30-routing.json")" '"inboundTag":[[:space:]]*\[[[:space:]]*"dokodemo-in"[[:space:]]*\]'
  assert_match "$(cat "$output_dir/server/30-routing.json")" '"domain":[[:space:]]*\[[[:space:]]*"addons.mozilla.org"[[:space:]]*\]'
  assert_match "$(cat "$output_dir/server/30-routing.json")" '"outboundTag":[[:space:]]*"block"'
  assert_match "$(cat "$output_dir/connection.txt")" 'Server Address: edge\.example\.com'
  assert_match "$(cat "$output_dir/connection.txt")" 'URI: vless://11111111-1111-1111-1111-111111111111@edge\.example\.com:443'
}

main "$@"

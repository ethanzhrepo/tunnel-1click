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
  export UUID="11111111-1111-1111-1111-111111111111"
  export REALITY_PRIVATE_KEY="private-key"
  export REALITY_PUBLIC_KEY="public-key"
  export REALITY_SHORT_ID="0123456789abcdef"
  export REALITY_TARGET="addons.mozilla.org:443"
  export REALITY_SERVER_NAME="addons.mozilla.org"
  export TLS_FINGERPRINT="chrome"

  t1c_render_snapshot "$snapshot_dir" "$output_dir"

  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"target":[[:space:]]*"addons.mozilla.org:443"'
  assert_match "$(cat "$output_dir/server/40-inbounds-reality.json")" '"id":[[:space:]]*"11111111-1111-1111-1111-111111111111"'
  assert_match "$(cat "$output_dir/connection.txt")" 'URI: vless://11111111-1111-1111-1111-111111111111@203\.0\.113\.10:443'
}

main "$@"

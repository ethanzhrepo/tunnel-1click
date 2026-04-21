#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/targets.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local targets_file connect_file

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT
  targets_file="$TMPDIR_FOR_TEST/reality-targets"
  connect_file="$TMPDIR_FOR_TEST/connect-address"

  cat >"$targets_file" <<'EOF'
# first comment

addons.mozilla.org:443
www.apple.com:443
EOF

  cat >"$connect_file" <<'EOF'
# preferred address
edge.example.com
EOF

  assert_eq "$(t1c_read_target_candidates "$targets_file")" $'addons.mozilla.org:443\nwww.apple.com:443'
  assert_eq "$(t1c_read_connect_address "$connect_file")" "edge.example.com"
  assert_eq "$(t1c_target_host "addons.mozilla.org:443")" "addons.mozilla.org"
  assert_eq "$(t1c_target_port "addons.mozilla.org:443")" "443"
}

main "$@"

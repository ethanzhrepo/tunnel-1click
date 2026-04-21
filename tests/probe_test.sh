#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local targets_file output

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT
  targets_file="$TMPDIR_FOR_TEST/reality-targets"

  cat >"$targets_file" <<'EOF'
addons.mozilla.org:443
www.apple.com:443
EOF

  output="$(
    T1C_PROBE_FIXTURES=$'addons.mozilla.org:443|ok|83\nwww.apple.com:443|ok|95' \
      bash "$ROOT_DIR/scripts/probe.sh" "$targets_file"
  )"

  assert_match "$output" 'BEST_TARGET=addons.mozilla.org:443'
  assert_match "$output" 'BEST_SERVER_NAME=addons.mozilla.org'
}

main "$@"

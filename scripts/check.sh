#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/targets.sh"

target="${1:-}"
[[ -n "$target" ]] || t1c_die "usage: ./check.sh host:port"

if output="$(t1c_emit_target_report "$target")"; then
  printf '%s\n' "$output"
  printf 'STATUS=ok\n'
else
  printf '%s\n' "$output"
  if ! grep -q '^REASON=' <<<"$output"; then
    printf 'REASON=target_check_failed\n'
  fi
  printf 'STATUS=fail\n'
  exit 1
fi

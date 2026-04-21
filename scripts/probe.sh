#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/targets.sh"

targets_file="${1:-$SCRIPT_DIR/../reality-targets}"
t1c_probe_best_target "$targets_file" || t1c_die "no valid REALITY target candidates"

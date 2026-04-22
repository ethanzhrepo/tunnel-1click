#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

main() {
  local workflow

  workflow="$ROOT_DIR/.github/workflows/pages-distribution.yml"

  [[ -f "$workflow" ]] || fail "expected pages distribution workflow to exist"

  assert_match "$(cat "$workflow")" '^name: Pages Distribution'
  assert_match "$(cat "$workflow")" 'workflow_dispatch:'
  assert_match "$(cat "$workflow")" 'push:'
  assert_match "$(cat "$workflow")" 'paths-ignore:'
  assert_match "$(cat "$workflow")" 'tunnel-1click-main\.tar\.gz'
  assert_match "$(cat "$workflow")" 'git ls-files .*:\(exclude\)tunnel-1click-main\.tar\.gz'
  assert_match "$(cat "$workflow")" 'git archive --format=tar\.gz --output=tunnel-1click-main\.tar\.gz HEAD "\$\{archive_paths\[@\]\}"'
  assert_match "$(cat "$workflow")" 'git status --short -- tunnel-1click-main\.tar\.gz'
  assert_match "$(cat "$workflow")" 'git add tunnel-1click-main\.tar\.gz'
  assert_match "$(cat "$workflow")" 'git push'
}

main "$@"

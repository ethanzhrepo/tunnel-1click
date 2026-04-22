#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

main() {
  local page copy_count

  page="$ROOT_DIR/index.html"

  [[ -f "$page" ]] || fail "expected index.html to exist"

  assert_match "$(cat "$page")" 'curl -fsSL https://0x99\.link/install\.sh \| sh'
  assert_match "$(cat "$page")" 'curl -fsSL https://0x99\.link/update\.sh \| sh'
  assert_match "$(cat "$page")" 'href="README\.md"'
  assert_match "$(cat "$page")" 'href="install\.sh"'
  assert_match "$(cat "$page")" 'href="update\.sh"'
  assert_match "$(cat "$page")" '>What It Sets Up<'
  assert_match "$(cat "$page")" '>Quick Use<'
  assert_match "$(cat "$page")" '>Docs<'
  assert_match "$(cat "$page")" 'systemctl start xray'
  assert_match "$(cat "$page")" 'systemctl restart xray'
  assert_match "$(cat "$page")" 'journalctl -u xray -n 50 --no-pager'
  assert_match "$(cat "$page")" 'tail -n 50 /var/log/xray/error\.log'
  assert_match "$(cat "$page")" 'data-copy-target='
  assert_match "$(cat "$page")" 'navigator\.clipboard\.writeText'
  assert_match "$(cat "$page")" 'Press Ctrl/Cmd\+C'
  assert_not_match "$(cat "$page")" 'class="copy-button-text"'
  assert_not_match "$(cat "$page")" '>Copy<'

  copy_count="$(grep -o 'class="copy-button"' "$page" | wc -l | tr -d ' ')"
  assert_eq "$copy_count" "5"
}

main "$@"

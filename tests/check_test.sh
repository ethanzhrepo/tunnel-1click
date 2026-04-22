#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

main() {
  local output

  output="$(
    T1C_CHECK_DNS_OK=1 \
    T1C_CHECK_TCP_OK=1 \
    T1C_CHECK_TLS_OK=1 \
    T1C_CHECK_TLS_VERSION="TLSv1.3" \
    T1C_CHECK_ALPN="h2" \
    T1C_CHECK_SAN_OK=1 \
    T1C_CHECK_LATENCY_MS=83 \
      bash "$ROOT_DIR/scripts/check.sh" addons.mozilla.org:443
  )"

  assert_match "$output" 'TARGET=addons.mozilla.org:443'
  assert_match "$output" 'STATUS=ok'

  output="$(
    T1C_CHECK_DNS_OK=1 \
    T1C_CHECK_TCP_OK=0 \
    T1C_CHECK_TLS_OK=1 \
    T1C_CHECK_TLS_VERSION="TLSv1.3" \
    T1C_CHECK_ALPN="h2" \
    T1C_CHECK_SAN_OK=1 \
    T1C_CHECK_LATENCY_MS=18 \
      bash "$ROOT_DIR/scripts/check.sh" addons.mozilla.org:443
  )"

  assert_match "$output" 'TCP_OK=1'
  assert_match "$output" 'TLS_OK=1'
  assert_match "$output" 'STATUS=ok'
}

main "$@"

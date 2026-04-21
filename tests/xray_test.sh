#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/xray.sh"

main() {
  assert_eq "$(t1c_xray_asset_name x86_64)" "Xray-linux-64.zip"
  assert_eq "$(t1c_xray_asset_name aarch64)" "Xray-linux-arm64-v8a.zip"
  assert_eq "$(t1c_xray_asset_name armv7l)" "Xray-linux-arm32-v7a.zip"

  assert_eq "$(printf '%s\n' '{"ip":"207.6.192.17"}' | t1c_extract_ipinfo_ip)" "207.6.192.17"
  assert_eq "$(printf '%s\n' 'Private key: private-test' | t1c_extract_private_key)" "private-test"
  assert_eq "$(printf '%s\n' 'Public key: public-test' | t1c_extract_public_key)" "public-test"
  assert_match "$(t1c_generate_short_id)" '^[0-9a-f]{16}$'
}

main "$@"

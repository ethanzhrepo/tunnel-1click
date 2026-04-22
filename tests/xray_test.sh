#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/xray.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local fake_xray

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT

  assert_eq "$(t1c_xray_asset_name x86_64)" "Xray-linux-64.zip"
  assert_eq "$(t1c_xray_asset_name aarch64)" "Xray-linux-arm64-v8a.zip"
  assert_eq "$(t1c_xray_asset_name armv7l)" "Xray-linux-arm32-v7a.zip"

  assert_eq "$(printf '%s\n' '{"ip":"207.6.192.17"}' | t1c_extract_ipinfo_ip)" "207.6.192.17"
  assert_eq "$(printf '%s\n' 'Private key: private-test' | t1c_extract_private_key)" "private-test"
  assert_eq "$(printf '%s\n' 'Public key: public-test' | t1c_extract_public_key)" "public-test"
  assert_eq "$(printf '%s\n' 'PrivateKey: private-test-2' | t1c_extract_private_key)" "private-test-2"
  assert_eq "$(printf '%s\n' 'Password (PublicKey): public-test-2' | t1c_extract_public_key)" "public-test-2"

  fake_xray="$TMPDIR_FOR_TEST/xray"
  cat >"$fake_xray" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  x25519)
    printf 'PrivateKey: private-live\nPassword (PublicKey): public-live\n'
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_xray"

  assert_eq "$(t1c_generate_reality_keypair "$fake_xray")" "private-live,public-live"
  assert_match "$(t1c_generate_short_id)" '^[0-9a-f]{16}$'
}

main "$@"

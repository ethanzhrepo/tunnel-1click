#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local snapshot_dir package_dir bin_dir share_dir conf_dir systemd_dir log_dir state_dir

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT

  snapshot_dir="$TMPDIR_FOR_TEST/snapshot"
  package_dir="$TMPDIR_FOR_TEST/package"
  bin_dir="$TMPDIR_FOR_TEST/bin"
  share_dir="$TMPDIR_FOR_TEST/share"
  conf_dir="$TMPDIR_FOR_TEST/conf.d"
  systemd_dir="$TMPDIR_FOR_TEST/systemd"
  log_dir="$TMPDIR_FOR_TEST/log"
  state_dir="$TMPDIR_FOR_TEST/state"

  mkdir -p \
    "$snapshot_dir/templates/server" \
    "$snapshot_dir/templates/systemd" \
    "$snapshot_dir/templates/client" \
    "$package_dir" \
    "$bin_dir" \
    "$share_dir" \
    "$conf_dir" \
    "$systemd_dir" \
    "$log_dir" \
    "$state_dir"

  cp "$ROOT_DIR/templates/server/"*.tpl "$snapshot_dir/templates/server/"
  cp "$ROOT_DIR/templates/systemd/"*.tpl "$snapshot_dir/templates/systemd/"
  cp "$ROOT_DIR/templates/client/"*.tpl "$snapshot_dir/templates/client/"
  printf 'v26.3.27\n' >"$snapshot_dir/version"

  cat >"$package_dir/xray" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "run" ]]; then
  exit 0
fi

printf 'Xray v26.3.27 (go1.26.1 linux/amd64)\n'
EOF
  chmod +x "$package_dir/xray"
  : >"$package_dir/geoip.dat"
  : >"$package_dir/geosite.dat"

  cat >"$bin_dir/xray" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "run" ]]; then
  exit 0
fi

printf 'Xray v26.3.23 (go1.26.1 linux/amd64)\n'
EOF
  chmod +x "$bin_dir/xray"

  cat >"$state_dir/install.env" <<'EOF'
XRAY_VERSION='v26.3.23'
XRAY_PORT='443'
SERVER_IP='198.51.100.1'
UUID='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
REALITY_PRIVATE_KEY='private-old'
REALITY_PUBLIC_KEY='public-old'
REALITY_SHORT_ID='0011223344556677'
REALITY_TARGET='addons.mozilla.org:443'
REALITY_SERVER_NAME='addons.mozilla.org'
TLS_FINGERPRINT='chrome'
EOF

  T1C_SKIP_ROOT_CHECK=1 \
  T1C_SKIP_SYSTEMD=1 \
  T1C_SNAPSHOT_DIR="$snapshot_dir" \
  T1C_XRAY_PACKAGE_DIR="$package_dir" \
  T1C_PUBLIC_IP="203.0.113.44" \
  T1C_BIN_DIR="$bin_dir" \
  T1C_SHARE_DIR="$share_dir" \
  T1C_CONF_DIR="$conf_dir" \
  T1C_SYSTEMD_DIR="$systemd_dir" \
  T1C_LOG_DIR="$log_dir" \
  T1C_STATE_DIR="$state_dir" \
    bash "$ROOT_DIR/scripts/host-update.sh"

  assert_eq "$(awk -F= '/^UUID=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
  assert_eq "$(awk -F= '/^XRAY_VERSION=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "v26.3.27"
  assert_eq "$(awk -F= '/^SERVER_IP=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "203.0.113.44"
  assert_match "$(cat "$state_dir/connection.txt")" '203\.0\.113\.44'
  assert_match "$(cat "$state_dir/connection.txt")" 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local snapshot_dir package_dir bin_dir share_dir conf_dir systemd_dir log_dir state_dir output

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

  cp "$ROOT_DIR/version" "$snapshot_dir/version"
  cp "$ROOT_DIR/templates/server/"*.tpl "$snapshot_dir/templates/server/"
  cp "$ROOT_DIR/templates/systemd/"*.tpl "$snapshot_dir/templates/systemd/"
  cp "$ROOT_DIR/templates/client/"*.tpl "$snapshot_dir/templates/client/"

  cat >"$package_dir/xray" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  uuid)
    printf 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa\n'
    ;;
  x25519)
    printf 'Private key: private-value\nPublic key: public-value\n'
    ;;
  run)
    exit 0
    ;;
  *)
    printf 'Xray v26.3.27 (go1.26.1 linux/amd64)\n'
    ;;
esac
EOF
  chmod +x "$package_dir/xray"
  : >"$package_dir/geoip.dat"
  : >"$package_dir/geosite.dat"

  if output="$(
    T1C_SKIP_ROOT_CHECK=1 \
    T1C_SKIP_SYSTEMD=1 \
    T1C_SKIP_DEPENDENCY_INSTALL=1 \
    T1C_PROBE_FIXTURES='addons.mozilla.org:443|fail|tcp_connect_failed' \
    T1C_INSTALL_TARGET_INPUT='' \
    T1C_INSTALL_CONNECT_ADDRESS_INPUT='' \
    T1C_DIG_OUTPUT='203.0.113.25' \
    T1C_SNAPSHOT_DIR="$snapshot_dir" \
    T1C_XRAY_PACKAGE_DIR="$package_dir" \
    T1C_PUBLIC_IP="203.0.113.25" \
    T1C_BIN_DIR="$bin_dir" \
    T1C_SHARE_DIR="$share_dir" \
    T1C_CONF_DIR="$conf_dir" \
    T1C_SYSTEMD_DIR="$systemd_dir" \
    T1C_LOG_DIR="$log_dir" \
    T1C_STATE_DIR="$state_dir" \
      bash "$ROOT_DIR/scripts/host-install.sh" 2>&1
  )"; then
    fail "expected install to fail when the only REALITY target is invalid"
  fi

  assert_match "$output" 'FAIL addons\.mozilla\.org:443 reason=tcp_connect_failed'
  assert_match "$output" 'ERROR: no valid REALITY target candidates'
}

main "$@"

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
    "$package_dir"

  cp "$ROOT_DIR/version" "$snapshot_dir/version"
  cp "$ROOT_DIR/templates/server/"*.tpl "$snapshot_dir/templates/server/"
  cp "$ROOT_DIR/templates/systemd/"*.tpl "$snapshot_dir/templates/systemd/"
  cp "$ROOT_DIR/templates/client/"*.tpl "$snapshot_dir/templates/client/"
  cat >"$snapshot_dir/reality-targets" <<'EOF'
addons.mozilla.org:443
www.apple.com:443
EOF
  printf 'edge.example.com\n' >"$snapshot_dir/connect-address"

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

  T1C_SKIP_ROOT_CHECK=1 \
  T1C_SKIP_SYSTEMD=1 \
  T1C_SKIP_DEPENDENCY_INSTALL=1 \
  T1C_PROBE_FIXTURES=$'addons.mozilla.org:443|ok|83\nwww.apple.com:443|ok|95' \
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
    bash "$ROOT_DIR/scripts/host-install.sh"

  assert_eq "$(awk -F= '/^UUID=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
  assert_eq "$(awk -F= '/^SERVER_IP=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "203.0.113.25"
  assert_eq "$(awk -F= '/^REALITY_TARGET=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "addons.mozilla.org:443"
  assert_eq "$(awk -F= '/^REALITY_SERVER_NAME=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "addons.mozilla.org"
  assert_eq "$(awk -F= '/^CONNECT_ADDRESS=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$state_dir/install.env")" "edge.example.com"
  assert_match "$(cat "$state_dir/connection.txt")" 'public-value'
  assert_match "$(cat "$state_dir/connection.txt")" 'Server Address: edge\.example\.com'
  assert_match "$(cat "$conf_dir/40-inbounds-reality.json")" '"tag":[[:space:]]*"dokodemo-in"'
  assert_match "$(cat "$conf_dir/40-inbounds-reality.json")" '"target":[[:space:]]*"127.0.0.1:4431"'
  assert_match "$(cat "$conf_dir/30-routing.json")" '"domain":[[:space:]]*\[[[:space:]]*"addons.mozilla.org"[[:space:]]*\]'
}

main "$@"

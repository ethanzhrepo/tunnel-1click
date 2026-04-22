#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

setup_install_fixture() {
  local base_dir="$1"
  local snapshot_dir="$base_dir/snapshot"
  local package_dir="$base_dir/package"

  mkdir -p \
    "$snapshot_dir/templates/server" \
    "$snapshot_dir/templates/systemd" \
    "$snapshot_dir/templates/client" \
    "$package_dir"

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
}

run_install_case() {
  local case_dir="$1"
  local target_input="$2"
  local connect_input="$3"
  local probe_fixtures="$4"
  local snapshot_dir="$case_dir/snapshot"
  local package_dir="$case_dir/package"
  local bin_dir="$case_dir/bin"
  local share_dir="$case_dir/share"
  local conf_dir="$case_dir/conf.d"
  local systemd_dir="$case_dir/systemd"
  local log_dir="$case_dir/log"
  local state_dir="$case_dir/state"

  mkdir -p "$bin_dir" "$share_dir" "$conf_dir" "$systemd_dir" "$log_dir" "$state_dir"

  T1C_SKIP_ROOT_CHECK=1 \
  T1C_SKIP_SYSTEMD=1 \
  T1C_SKIP_DEPENDENCY_INSTALL=1 \
  T1C_PROBE_FIXTURES="$probe_fixtures" \
  T1C_INSTALL_TARGET_INPUT="$target_input" \
  T1C_INSTALL_CONNECT_ADDRESS_INPUT="$connect_input" \
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
    bash "$ROOT_DIR/scripts/host-install.sh" >/dev/null
}

main() {
  local default_case custom_case

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT

  default_case="$TMPDIR_FOR_TEST/default"
  custom_case="$TMPDIR_FOR_TEST/custom"

  setup_install_fixture "$default_case"
  run_install_case "$default_case" "" "" 'addons.mozilla.org:443|ok|83'
  assert_eq "$(cat "$default_case/state/reality-targets")" "addons.mozilla.org:443"
  assert_eq "$(wc -c <"$default_case/state/connect-address" | tr -d '[:space:]')" "0"
  assert_eq "$(awk -F= '/^CONNECT_ADDRESS=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$default_case/state/install.env")" "203.0.113.25"

  setup_install_fixture "$custom_case"
  run_install_case "$custom_case" "www.apple.com:443" "edge.example.com" $'www.apple.com:443|ok|95'
  assert_eq "$(cat "$custom_case/state/reality-targets")" "www.apple.com:443"
  assert_eq "$(cat "$custom_case/state/connect-address")" "edge.example.com"
  assert_eq "$(awk -F= '/^REALITY_TARGET=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$custom_case/state/install.env")" "www.apple.com:443"
  assert_eq "$(awk -F= '/^CONNECT_ADDRESS=/{gsub(/^'\''|'\''$/, "", $2); print $2}' "$custom_case/state/install.env")" "edge.example.com"
}

main "$@"

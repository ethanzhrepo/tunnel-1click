#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/common.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local os_release state_dir conf_dir bin_dir share_dir systemd_dir log_dir

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT

  state_dir="$TMPDIR_FOR_TEST/state"
  conf_dir="$TMPDIR_FOR_TEST/conf.d"
  bin_dir="$TMPDIR_FOR_TEST/bin"
  share_dir="$TMPDIR_FOR_TEST/share"
  systemd_dir="$TMPDIR_FOR_TEST/systemd"
  log_dir="$TMPDIR_FOR_TEST/log"
  os_release="$TMPDIR_FOR_TEST/os-release"

  cat >"$os_release" <<'EOF'
ID=ubuntu
ID_LIKE=debian
EOF
  assert_eq "$(t1c_detect_distro_family_from_file "$os_release")" "debian"

  cat >"$os_release" <<'EOF'
ID=rocky
ID_LIKE="rhel centos fedora"
EOF
  assert_eq "$(t1c_detect_distro_family_from_file "$os_release")" "rhel"

  ID=ignored
  ID_LIKE=debian
  cat >"$os_release" <<'EOF'
ID=unknown
EOF
  if t1c_detect_distro_family_from_file "$os_release"; then
    fail 'expected stale ambient ID_LIKE not to affect os-release detection'
  fi

  assert_eq "$(t1c_normalize_arch x86_64)" "x86_64"
  assert_eq "$(t1c_normalize_arch arm64)" "aarch64"
  assert_eq "$(T1C_STATE_DIR="$state_dir" t1c_state_dir)" "$state_dir"
  assert_eq "$(T1C_CONF_DIR="$conf_dir" t1c_conf_dir)" "$conf_dir"
  assert_eq "$(T1C_BIN_DIR="$bin_dir" t1c_bin_dir)" "$bin_dir"
  assert_eq "$(T1C_SHARE_DIR="$share_dir" t1c_share_dir)" "$share_dir"
  assert_eq "$(T1C_SYSTEMD_DIR="$systemd_dir" t1c_systemd_dir)" "$systemd_dir"
  assert_eq "$(T1C_LOG_DIR="$log_dir" t1c_log_dir)" "$log_dir"
}

main "$@"

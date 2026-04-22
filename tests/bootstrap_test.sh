#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/repo.sh"
source "$ROOT_DIR/scripts/lib/state.sh"

assert_bootstrap_contract() {
  local script_path="$1"
  local expected_delegate="$2"
  local tmpdir copied_script download_file exec_file args_file

  tmpdir="$(make_temp_dir)"
  copied_script="$tmpdir/$(basename "$script_path")"
  download_file="$tmpdir/fetch"
  exec_file="$tmpdir/exec"
  args_file="$tmpdir/args"

  cp "$ROOT_DIR/$script_path" "$copied_script"
  T1C_BOOTSTRAP_SKIP_MAIN=1 . "$copied_script"

  assert_eq "$(t1c_bootstrap_snapshot_url)" "https://0x99.link/tunnel-1click-main.tar.gz"
  assert_eq "$(type -t t1c_bootstrap_fallback_snapshot_url || true)" ""
  assert_eq "$(t1c_bootstrap_delegate_path)" "$expected_delegate"

  t1c_bootstrap_fetch_snapshot() {
    local extracted_dir="$1/extracted"

    printf '%s\n' "$1" >"$download_file"
    mkdir -p "$extracted_dir/$(dirname "$expected_delegate")"
    cat >"$extracted_dir/$expected_delegate" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$extracted_dir/$expected_delegate"
    printf '%s\n' "$extracted_dir"
  }

  t1c_bootstrap_exec_delegate() {
    printf '%s\n' "$1" >"$exec_file"
    shift
    printf '%s\n' "$*" >"$args_file"
  }

  t1c_bootstrap_main alpha beta

  assert_match "$(sed -n '1p' "$download_file")" '.+'
  assert_eq "$(sed -n '1p' "$exec_file")" "$(sed -n '1p' "$download_file")/extracted/$expected_delegate"
  assert_eq "$(sed -n '1p' "$args_file")" "alpha beta"
}

assert_bootstrap_executable() {
  local script_path="$1"
  local expected_delegate="$2"
  local tmpdir fakebin template_root isolated_root isolated_script delegate_file args_file

  tmpdir="$(make_temp_dir)"
  fakebin="$tmpdir/bin"
  template_root="$tmpdir/template"
  isolated_root="$tmpdir/isolated"
  isolated_script="$isolated_root/$(basename "$script_path")"
  delegate_file="$tmpdir/delegate"
  args_file="$tmpdir/args"

  mkdir -p "$fakebin" "$template_root/$(dirname "$expected_delegate")" "$isolated_root"
  cp "$ROOT_DIR/$script_path" "$isolated_script"

  cat >"$fakebin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

archive=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o)
      archive="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

: >"$archive"
EOF
  chmod +x "$fakebin/curl"

  cat >"$fakebin/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workdir=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -C)
      workdir="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "$workdir/$(dirname "$T1C_BOOTSTRAP_DELEGATE_PATH")"
cp "$T1C_BOOTSTRAP_TEMPLATE_ROOT/$T1C_BOOTSTRAP_DELEGATE_PATH" "$workdir/$T1C_BOOTSTRAP_DELEGATE_PATH"
chmod +x "$workdir/$T1C_BOOTSTRAP_DELEGATE_PATH"
EOF
  chmod +x "$fakebin/tar"

  cat >"$template_root/$expected_delegate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$0" >"$T1C_BOOTSTRAP_DELEGATE_FILE"
printf '%s\n' "$*" >"$T1C_BOOTSTRAP_ARGS_FILE"
EOF
  chmod +x "$template_root/$expected_delegate"

  PATH="$fakebin:$PATH" \
  T1C_BOOTSTRAP_TEMPLATE_ROOT="$template_root" \
  T1C_BOOTSTRAP_DELEGATE_PATH="$expected_delegate" \
  T1C_BOOTSTRAP_DELEGATE_FILE="$delegate_file" \
  T1C_BOOTSTRAP_ARGS_FILE="$args_file" \
    sh "$isolated_script" alpha beta

  assert_match "$(sed -n '1p' "$delegate_file")" "/$expected_delegate$"
  assert_eq "$(sed -n '1p' "$args_file")" "alpha beta"
}

assert_state_contract() {
  local tmpdir state_file complex_value

  tmpdir="$(make_temp_dir)"
  state_file="$tmpdir/state/install.env"
  complex_value="$tmpdir/rendered dir with spaces \$(printf x) ; semi"

  assert_eq "$(T1C_STATE_DIR="$tmpdir/state" t1c_state_file)" "$tmpdir/state/install.env"
  assert_eq "$(T1C_STATE_DIR="$tmpdir/state" t1c_connection_file)" "$tmpdir/state/connection.txt"
  assert_eq "$(T1C_STATE_DIR="$tmpdir/state" t1c_rendered_dir)" "$tmpdir/state/rendered"
  assert_eq "$(T1C_STATE_DIR="$tmpdir/state" t1c_cache_dir)" "$tmpdir/state/cache"

  t1c_write_state_file \
    "$state_file" \
    "T1C_CONNECTION_FILE=$tmpdir/connection.sock" \
    "T1C_RENDERED_DIR=$complex_value" \
    "T1C_CACHE_DIR=$tmpdir/cache"

  unset T1C_CONNECTION_FILE T1C_RENDERED_DIR T1C_CACHE_DIR
  t1c_load_state_file "$state_file"

  assert_eq "$T1C_CONNECTION_FILE" "$tmpdir/connection.sock"
  assert_eq "$T1C_RENDERED_DIR" "$complex_value"
  assert_eq "$T1C_CACHE_DIR" "$tmpdir/cache"
}

assert_read_version_file() {
  local tmpdir version_file

  tmpdir="$(make_temp_dir)"
  version_file="$tmpdir/version"
  printf '  v1.2.3\n' >"$version_file"

  assert_eq "$(t1c_read_version_file "$version_file")" "v1.2.3"
}

assert_repo_snapshot_urls() {
  assert_eq "$(t1c_repo_snapshot_url)" "https://0x99.link/tunnel-1click-main.tar.gz"
  assert_eq "$(type -t t1c_repo_fallback_snapshot_url || true)" ""
}

main() {
  assert_bootstrap_contract "install.sh" "scripts/host-install.sh"
  assert_bootstrap_contract "update.sh" "scripts/host-update.sh"
  assert_bootstrap_executable "install.sh" "scripts/host-install.sh"
  assert_bootstrap_executable "update.sh" "scripts/host-update.sh"
  assert_repo_snapshot_urls
  assert_state_contract
  assert_read_version_file
}

main "$@"

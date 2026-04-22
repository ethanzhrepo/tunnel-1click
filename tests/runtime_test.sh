#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local fake_bin command_log original_path

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT

  fake_bin="$TMPDIR_FOR_TEST/bin"
  command_log="$TMPDIR_FOR_TEST/systemctl.log"
  original_path="$PATH"
  mkdir -p "$fake_bin"

  cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$T1C_SYSTEMCTL_LOG"

case "${1:-}" in
  is-active)
    if [[ "${2:-}" == "--quiet" ]]; then
      [[ "${T1C_SYSTEMCTL_ACTIVE:-0}" == "1" ]]
      exit
    fi
    printf 'active\n'
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$fake_bin/systemctl"

  export PATH="$fake_bin:$original_path"
  # shellcheck disable=SC1090
  source "$ROOT_DIR/scripts/lib/runtime.sh"

  : >"$command_log"
  T1C_SYSTEMCTL_LOG="$command_log" T1C_SYSTEMCTL_ACTIVE=1 t1c_enable_and_start_service
  assert_match "$(cat "$command_log")" '^daemon-reload'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])enable xray($|[[:space:]])'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])is-active --quiet xray($|[[:space:]])'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])restart xray($|[[:space:]])'
  assert_not_match "$(cat "$command_log")" '(^|[[:space:]])start xray($|[[:space:]])'

  : >"$command_log"
  T1C_SYSTEMCTL_LOG="$command_log" T1C_SYSTEMCTL_ACTIVE=0 t1c_enable_and_start_service
  assert_match "$(cat "$command_log")" '^daemon-reload'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])enable xray($|[[:space:]])'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])is-active --quiet xray($|[[:space:]])'
  assert_match "$(cat "$command_log")" '(^|[[:space:]])start xray($|[[:space:]])'
  assert_not_match "$(cat "$command_log")" '(^|[[:space:]])restart xray($|[[:space:]])'
}

main "$@"

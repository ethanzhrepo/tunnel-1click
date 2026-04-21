#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

t1c_state_quote() {
  local value="$1"
  value="${value//\'/\'\"\'\"\'}"
  printf "'%s'" "$value"
}

t1c_state_file() {
  printf '%s\n' "$(t1c_state_dir)/install.env"
}

t1c_connection_file() {
  printf '%s\n' "$(t1c_state_dir)/connection.txt"
}

t1c_rendered_dir() {
  printf '%s\n' "$(t1c_state_dir)/rendered"
}

t1c_cache_dir() {
  printf '%s\n' "${T1C_CACHE_DIR:-$(t1c_state_dir)/cache}"
}

t1c_write_state_file() {
  local state_file="$1"
  local state_dir assignment key value
  shift || true

  state_dir="$(dirname "$state_file")"
  mkdir -p "$state_dir"
  : >"$state_file"

  for assignment in "$@"; do
    case "$assignment" in
      *=*)
        key="${assignment%%=*}"
        value="${assignment#*=}"
        ;;
      *)
        key="$assignment"
        value=""
        ;;
    esac
    printf '%s=%s\n' "$key" "$(t1c_state_quote "$value")" >>"$state_file"
  done
}

t1c_load_state_file() {
  local state_file="$1"

  [[ -f "$state_file" ]] || return 1
  # shellcheck disable=SC1090
  source "$state_file"
}

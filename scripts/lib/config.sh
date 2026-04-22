#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/targets.sh"

t1c_reality_targets_file() {
  printf '%s\n' "${T1C_REALITY_TARGETS_FILE:-$(t1c_state_dir)/reality-targets}"
}

t1c_connect_address_file() {
  printf '%s\n' "${T1C_CONNECT_ADDRESS_FILE:-$(t1c_state_dir)/connect-address}"
}

t1c_default_reality_target() {
  printf 'addons.mozilla.org:443\n'
}

t1c_normalize_target_candidate() {
  local raw="$1"
  local host port

  raw="$(t1c_trim_line "$raw")"
  [[ -n "$raw" ]] || return 1

  raw="${raw#http://}"
  raw="${raw#https://}"

  if [[ "$raw" =~ [[:space:]] ]]; then
    host="${raw%%[[:space:]]*}"
    port="${raw##*[[:space:]]}"
    raw="${host%/}:$port"
  fi

  raw="${raw%/}"
  if [[ "$raw" != *:* ]]; then
    raw="${raw}:443"
  fi

  host="${raw%:*}"
  port="${raw##*:}"

  [[ -n "$host" ]] || return 1
  [[ "$port" =~ ^[0-9]+$ ]] || return 1

  printf '%s\n' "${host}:${port}"
}

t1c_config_prompt_input() {
  local prompt="$1"
  local env_name="${2:-}"
  local input=""

  if [[ -n "$env_name" && "${!env_name+x}" == "x" ]]; then
    printf '%s\n' "${!env_name}"
    return 0
  fi

  if [[ -r /dev/tty ]]; then
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r input </dev/tty || input=""
  fi

  printf '%s\n' "$input"
}

t1c_resolve_targets_file() {
  local snapshot_dir="$1"
  local runtime_file

  runtime_file="$(t1c_reality_targets_file)"
  if [[ -f "$runtime_file" ]]; then
    printf '%s\n' "$runtime_file"
  else
    printf '%s\n' "$snapshot_dir/reality-targets"
  fi
}

t1c_resolve_connect_address_file() {
  local snapshot_dir="$1"
  local runtime_file

  runtime_file="$(t1c_connect_address_file)"
  if [[ -f "$runtime_file" ]]; then
    printf '%s\n' "$runtime_file"
  else
    printf '%s\n' "$snapshot_dir/connect-address"
  fi
}

t1c_install_initialize_config() {
  local server_ip="$1"
  local targets_file connect_file target_input target_value connect_input

  mkdir -p "$(t1c_state_dir)"

  targets_file="$(t1c_reality_targets_file)"
  if ! [[ -s "$targets_file" ]] || [[ -z "$(t1c_read_target_candidates "$targets_file" 2>/dev/null || true)" ]]; then
    target_input="$(t1c_config_prompt_input "REALITY target [$(t1c_default_reality_target)]: " T1C_INSTALL_TARGET_INPUT)"
    if [[ -z "$target_input" ]]; then
      target_value="$(t1c_default_reality_target)"
    else
      target_value="$(t1c_normalize_target_candidate "$target_input")" || t1c_die 'invalid REALITY target'
    fi
    printf '%s\n' "$target_value" >"$targets_file"
  fi

  connect_file="$(t1c_connect_address_file)"
  if [[ ! -f "$connect_file" ]]; then
    connect_input="$(t1c_config_prompt_input "Connect address (leave empty to use ${server_ip}): " T1C_INSTALL_CONNECT_ADDRESS_INPUT)"
    connect_input="$(t1c_trim_line "$connect_input")"

    : >"$connect_file"
    if [[ -n "$connect_input" ]]; then
      t1c_validate_connect_address "$connect_input" "$server_ip" || t1c_die 'connect-address does not resolve to this server'
      printf '%s\n' "$connect_input" >"$connect_file"
    fi
  fi
}

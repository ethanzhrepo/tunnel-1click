#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

t1c_trim_line() {
  local line="$1"
  line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s\n' "$line"
}

t1c_read_target_candidates() {
  local path="$1"
  local line out=""

  [[ -f "$path" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(t1c_trim_line "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    out+="${out:+$'\n'}$line"
  done <"$path"

  printf '%s\n' "$out"
}

t1c_read_connect_address() {
  local path="$1"
  local line

  [[ -f "$path" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(t1c_trim_line "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    printf '%s\n' "$line"
    return 0
  done <"$path"
}

t1c_target_host() {
  printf '%s\n' "${1%:*}"
}

t1c_target_port() {
  printf '%s\n' "${1##*:}"
}

t1c_lookup_ipv4() {
  if [[ -n "${T1C_DIG_OUTPUT:-}" ]]; then
    printf '%s\n' "$T1C_DIG_OUTPUT"
    return 0
  fi

  dig +short A "$1" | awk 'NF'
}

t1c_validate_connect_address() {
  local connect_address="$1"
  local public_ip="$2"
  local resolved

  if t1c_is_ipv4 "$connect_address"; then
    [[ "$connect_address" == "$public_ip" ]]
    return
  fi

  resolved="$(t1c_lookup_ipv4 "$connect_address")"
  grep -Fx "$public_ip" <<<"$resolved" >/dev/null 2>&1
}

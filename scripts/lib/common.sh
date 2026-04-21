#!/usr/bin/env bash
set -euo pipefail

t1c_log() {
  printf '[tunnel-1click] %s\n' "$*"
}

t1c_die() {
  printf '[tunnel-1click] ERROR: %s\n' "$*" >&2
  exit 1
}

t1c_require_root() {
  if [[ "${T1C_SKIP_ROOT_CHECK:-0}" == "1" ]]; then
    return 0
  fi

  [[ "$(id -u)" -eq 0 ]] || t1c_die 'Please rerun as root, for example: curl ... | sudo sh'
}

t1c_os_release_value() {
  local os_release_file="$1"
  local key="$2"
  local line value

  line="$(grep -m1 -E "^[[:space:]]*${key}=" "$os_release_file" || true)"
  [[ -n "$line" ]] || return 1

  value="${line#*=}"
  value="${value%%#*}"
  value="${value%$'\r'}"

  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
    \'*\')
      value="${value#\'}"
      value="${value%\'}"
      ;;
  esac

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

t1c_detect_distro_family_from_file() {
  local os_release_file="$1"
  local id=""
  local id_like=""

  id="$(t1c_os_release_value "$os_release_file" ID || true)"
  id_like="$(t1c_os_release_value "$os_release_file" ID_LIKE || true)"

  case "$id" in
    ubuntu|debian)
      printf 'debian\n'
      ;;
    centos|rhel|rocky|almalinux)
      printf 'rhel\n'
      ;;
    *)
      case "$id_like" in
        *debian*)
          printf 'debian\n'
          ;;
        *rhel*|*fedora*|*centos*)
          printf 'rhel\n'
          ;;
        *)
          return 1
          ;;
      esac
      ;;
  esac
}

t1c_normalize_arch() {
  local raw_arch="$1"

  case "$raw_arch" in
    x86_64|amd64)
      printf 'x86_64\n'
      ;;
    aarch64|arm64)
      printf 'aarch64\n'
      ;;
    armv7l|armv7)
      printf 'armv7l\n'
      ;;
    *)
      printf '%s\n' "$raw_arch"
      ;;
  esac
}

t1c_detect_arch() {
  t1c_normalize_arch "$(uname -m)"
}

t1c_state_dir() {
  printf '%s\n' "${T1C_STATE_DIR:-/var/lib/tunnel-1click}"
}

t1c_conf_dir() {
  printf '%s\n' "${T1C_CONF_DIR:-/usr/local/etc/xray/conf.d}"
}

t1c_bin_dir() {
  printf '%s\n' "${T1C_BIN_DIR:-/usr/local/bin}"
}

t1c_share_dir() {
  printf '%s\n' "${T1C_SHARE_DIR:-/usr/local/share/xray}"
}

t1c_systemd_dir() {
  printf '%s\n' "${T1C_SYSTEMD_DIR:-/etc/systemd/system}"
}

t1c_log_dir() {
  printf '%s\n' "${T1C_LOG_DIR:-/var/log/xray}"
}

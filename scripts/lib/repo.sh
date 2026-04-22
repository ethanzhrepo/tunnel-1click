#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

t1c_repo_name() {
  printf '%s\n' "${T1C_REPO_NAME:-tunnel-1click}"
}

t1c_repo_ref() {
  printf '%s\n' "${T1C_REPO_REF:-main}"
}

t1c_repo_site_url() {
  printf '%s\n' "${T1C_REPO_SITE_URL:-https://0x99.link}"
}

t1c_repo_snapshot_name() {
  printf '%s-%s.tar.gz\n' "$(t1c_repo_name)" "$(t1c_repo_ref)"
}

t1c_repo_snapshot_url() {
  printf '%s/%s\n' "$(t1c_repo_site_url)" "$(t1c_repo_snapshot_name)"
}

t1c_fetch_repo_snapshot() {
  local workdir="$1"
  local archive

  mkdir -p "$workdir"
  archive="$workdir/repo-snapshot.tar.gz"

  curl -fsSL "$(t1c_repo_snapshot_url)" -o "$archive"
  tar -xzf "$archive" -C "$workdir" --strip-components=1
  printf '%s\n' "$workdir"
}

t1c_read_version_file() {
  local path="$1"
  local version=""

  IFS= read -r version <"$path" || true
  version="${version%$'\r'}"
  version="${version#"${version%%[![:space:]]*}"}"
  version="${version%"${version##*[![:space:]]}"}"
  printf '%s\n' "$version"
}

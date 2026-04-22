#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

latest_version="${1:-}"
version_file="${2:-$ROOT_DIR/version}"

[[ -n "$latest_version" ]] || {
  printf 'usage: %s <latest-version> [version-file]\n' "$0" >&2
  exit 1
}

current_version=""
IFS= read -r current_version <"$version_file" || true
current_version="${current_version%$'\r'}"

printf 'CURRENT_VERSION=%s\n' "$current_version"
printf 'LATEST_VERSION=%s\n' "$latest_version"

if [[ "$current_version" == "$latest_version" ]]; then
  printf 'UPDATED=0\n'
  exit 0
fi

printf '%s\n' "$latest_version" >"$version_file"
printf 'UPDATED=1\n'

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

TMPDIR_FOR_TEST=""

cleanup_tmpdir() {
  rm -rf "${TMPDIR_FOR_TEST:-}"
}

main() {
  local version_file output

  TMPDIR_FOR_TEST="$(make_temp_dir)"
  trap cleanup_tmpdir EXIT
  version_file="$TMPDIR_FOR_TEST/version"

  printf 'v26.3.27\n' >"$version_file"

  output="$(bash "$ROOT_DIR/scripts/update-xray-version.sh" v26.3.28 "$version_file")"
  assert_match "$output" 'CURRENT_VERSION=v26\.3\.27'
  assert_match "$output" 'LATEST_VERSION=v26\.3\.28'
  assert_match "$output" 'UPDATED=1'
  assert_eq "$(cat "$version_file")" "v26.3.28"

  output="$(bash "$ROOT_DIR/scripts/update-xray-version.sh" v26.3.28 "$version_file")"
  assert_match "$output" 'UPDATED=0'
  assert_eq "$(cat "$version_file")" "v26.3.28"
}

main "$@"

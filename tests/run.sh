#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$#" -eq 0 ]]; then
  printf 'usage: %s tests/file_test.sh [...]\n' "$0" >&2
  exit 1
fi

for test_file in "$@"; do
  printf '==> %s\n' "$test_file"
  bash "$ROOT_DIR/$test_file"
done

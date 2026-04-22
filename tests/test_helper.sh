#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [[ "$actual" == "$expected" ]] || fail "expected [$expected] but got [$actual]"
}

assert_match() {
  local actual="$1"
  local pattern="$2"
  [[ "$actual" =~ $pattern ]] || fail "expected [$actual] to match [$pattern]"
}

assert_not_match() {
  local actual="$1"
  local pattern="$2"
  [[ ! "$actual" =~ $pattern ]] || fail "expected [$actual] not to match [$pattern]"
}

make_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/t1c-test.XXXXXX"
}

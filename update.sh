#!/bin/sh

t1c_bootstrap_snapshot_url() {
  printf '%s\n' 'https://github.com/ethanzhrepo/tunnel-1click/archive/refs/heads/main.tar.gz'
}

t1c_bootstrap_delegate_path() {
  printf '%s\n' 'scripts/host-update.sh'
}

t1c_bootstrap_exec_delegate() {
  exec bash "$@"
}

t1c_bootstrap_fetch_snapshot() {
  workdir="$1"
  archive="$workdir/bootstrap.tar.gz"

  mkdir -p "$workdir"
  curl -fsSL "$(t1c_bootstrap_snapshot_url)" -o "$archive"
  tar -xzf "$archive" -C "$workdir" --strip-components=1
  printf '%s\n' "$workdir"
}

t1c_bootstrap_main() {
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/t1c-bootstrap.XXXXXX")"
  snapshot_dir="$(t1c_bootstrap_fetch_snapshot "$workdir")"
  delegate="$snapshot_dir/$(t1c_bootstrap_delegate_path)"

  t1c_bootstrap_exec_delegate "$delegate" "$@"
}

if [ "${T1C_BOOTSTRAP_SKIP_MAIN:-0}" != "1" ]; then
  set -eu
  t1c_bootstrap_main "$@"
fi

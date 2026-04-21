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

t1c_target_dns_ok() {
  local host="$1"

  case "${T1C_CHECK_DNS_OK:-}" in
    1) return 0 ;;
    0) return 1 ;;
  esac

  [[ -n "$(t1c_lookup_ipv4 "$host")" ]]
}

t1c_target_tcp_ok() {
  local host="$1"
  local port="$2"

  case "${T1C_CHECK_TCP_OK:-}" in
    1) return 0 ;;
    0) return 1 ;;
  esac

  if command -v timeout >/dev/null 2>&1; then
    timeout "${T1C_CHECK_TIMEOUT_SEC:-8}" bash -c "exec 3<>/dev/tcp/$0/$1" "$host" "$port" >/dev/null 2>&1
  else
    bash -c "exec 3<>/dev/tcp/$0/$1" "$host" "$port" >/dev/null 2>&1
  fi
}

t1c_target_tls_output() {
  local host="$1"
  local port="$2"

  if [[ -n "${T1C_CHECK_TLS_OUTPUT:-}" ]]; then
    printf '%s\n' "$T1C_CHECK_TLS_OUTPUT"
    return 0
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "${T1C_CHECK_TIMEOUT_SEC:-8}" \
      openssl s_client -connect "${host}:${port}" -servername "$host" -alpn h2 -showcerts </dev/null 2>&1
  else
    openssl s_client -connect "${host}:${port}" -servername "$host" -alpn h2 -showcerts </dev/null 2>&1
  fi
}

t1c_target_tls_ok() {
  local host="$1"
  local port="$2"

  case "${T1C_CHECK_TLS_OK:-}" in
    1) return 0 ;;
    0) return 1 ;;
  esac

  t1c_target_tls_output "$host" "$port" >/dev/null
}

t1c_target_tls_version() {
  local host="$1"
  local port="$2"
  local output

  if [[ -n "${T1C_CHECK_TLS_VERSION:-}" ]]; then
    printf '%s\n' "$T1C_CHECK_TLS_VERSION"
    return 0
  fi

  output="$(t1c_target_tls_output "$host" "$port")"
  sed -n 's/^[[:space:]]*Protocol[[:space:]]*:[[:space:]]*//p' <<<"$output" | head -n1
}

t1c_target_alpn() {
  local host="$1"
  local port="$2"
  local output

  if [[ -n "${T1C_CHECK_ALPN:-}" ]]; then
    printf '%s\n' "$T1C_CHECK_ALPN"
    return 0
  fi

  output="$(t1c_target_tls_output "$host" "$port")"
  sed -n 's/^ALPN protocol:[[:space:]]*//p' <<<"$output" | head -n1
}

t1c_target_leaf_cert() {
  local host="$1"
  local port="$2"
  local output

  output="$(t1c_target_tls_output "$host" "$port")"
  awk '/-----BEGIN CERTIFICATE-----/{flag=1} flag{print} /-----END CERTIFICATE-----/{exit}' <<<"$output"
}

t1c_target_san_ok() {
  local host="$1"
  local port="$2"
  local cert

  case "${T1C_CHECK_SAN_OK:-}" in
    1) return 0 ;;
    0) return 1 ;;
  esac

  cert="$(t1c_target_leaf_cert "$host" "$port")"
  [[ -n "$cert" ]] || return 1
  openssl x509 -noout -ext subjectAltName <<<"$cert" 2>/dev/null | grep -F "DNS:${host}" >/dev/null 2>&1
}

t1c_now_ms() {
  if date +%s%3N >/dev/null 2>&1; then
    date +%s%3N
  else
    printf '%s000\n' "$(date +%s)"
  fi
}

t1c_target_latency_ms() {
  local host="$1"
  local port="$2"
  local start_ms end_ms

  if [[ -n "${T1C_CHECK_LATENCY_MS:-}" ]]; then
    printf '%s\n' "$T1C_CHECK_LATENCY_MS"
    return 0
  fi

  start_ms="$(t1c_now_ms)"
  t1c_target_tls_output "$host" "$port" >/dev/null
  end_ms="$(t1c_now_ms)"
  printf '%s\n' "$((end_ms - start_ms))"
}

t1c_emit_target_report() {
  local target="$1"
  local host port dns_ok tcp_ok tls_ok tls_version alpn_h2 san_ok latency_ms reason=""

  host="$(t1c_target_host "$target")"
  port="$(t1c_target_port "$target")"

  printf 'TARGET=%s\n' "$target"

  if [[ -z "$host" || ! "$port" =~ ^[0-9]+$ ]]; then
    printf 'DNS_OK=0\nTCP_OK=0\nTLS_OK=0\nTLS_VERSION=\nALPN_H2=0\nSAN_MATCH=0\nLATENCY_MS=\n'
    printf 'REASON=invalid_target_format\n'
    return 1
  fi

  if t1c_target_dns_ok "$host"; then dns_ok=1; else dns_ok=0; reason="${reason:-dns_lookup_failed}"; fi
  if t1c_target_tcp_ok "$host" "$port"; then tcp_ok=1; else tcp_ok=0; reason="${reason:-tcp_connect_failed}"; fi
  if t1c_target_tls_ok "$host" "$port"; then tls_ok=1; else tls_ok=0; reason="${reason:-tls_handshake_failed}"; fi
  tls_version="$(t1c_target_tls_version "$host" "$port" || true)"
  if [[ "$tls_version" == "TLSv1.3" ]]; then
    :
  else
    reason="${reason:-unexpected_tls_version}"
  fi
  if [[ "$(t1c_target_alpn "$host" "$port" || true)" == "h2" ]]; then
    alpn_h2=1
  else
    alpn_h2=0
    reason="${reason:-missing_h2}"
  fi
  if t1c_target_san_ok "$host" "$port"; then
    san_ok=1
  else
    san_ok=0
    reason="${reason:-san_mismatch}"
  fi
  latency_ms="$(t1c_target_latency_ms "$host" "$port" || true)"

  printf 'DNS_OK=%s\n' "$dns_ok"
  printf 'TCP_OK=%s\n' "$tcp_ok"
  printf 'TLS_OK=%s\n' "$tls_ok"
  printf 'TLS_VERSION=%s\n' "$tls_version"
  printf 'ALPN_H2=%s\n' "$alpn_h2"
  printf 'SAN_MATCH=%s\n' "$san_ok"
  printf 'LATENCY_MS=%s\n' "$latency_ms"

  [[ -z "$reason" ]]
}

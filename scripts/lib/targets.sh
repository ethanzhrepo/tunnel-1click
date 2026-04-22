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

  if command -v dig >/dev/null 2>&1; then
    dig +short A "$1" | awk 'NF'
    return 0
  fi

  if command -v getent >/dev/null 2>&1; then
    getent ahostsv4 "$1" | awk '{print $1}' | awk 'NF' | sort -u
    return 0
  fi

  return 1
}

t1c_check_fixture_line_for_target() {
  local target="$1"
  local line fixture_target

  [[ -n "${T1C_CHECK_FIXTURES:-}" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    fixture_target="${line%%|*}"
    [[ "$fixture_target" == "$target" ]] || continue
    printf '%s\n' "$line"
    return 0
  done <<<"$T1C_CHECK_FIXTURES"

  return 1
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
  local host port dns_ok tcp_ok tls_ok tls_version alpn_h2 san_ok latency_ms reason="" fixture_line fixture_status fixture_value

  host="$(t1c_target_host "$target")"
  port="$(t1c_target_port "$target")"

  printf 'TARGET=%s\n' "$target"

  if fixture_line="$(t1c_check_fixture_line_for_target "$target")"; then
    fixture_status="${fixture_line#*|}"
    fixture_status="${fixture_status%%|*}"
    fixture_value="${fixture_line##*|}"

    if [[ "$fixture_status" == "ok" ]]; then
      printf 'DNS_OK=1\nTCP_OK=1\nTLS_OK=1\nTLS_VERSION=TLSv1.3\nALPN_H2=1\nSAN_MATCH=1\nLATENCY_MS=%s\n' "$fixture_value"
      return 0
    fi

    printf 'DNS_OK=0\nTCP_OK=0\nTLS_OK=0\nTLS_VERSION=\nALPN_H2=0\nSAN_MATCH=0\nLATENCY_MS=\n'
    printf 'REASON=%s\n' "$fixture_value"
    return 1
  fi

  if [[ -z "$host" || ! "$port" =~ ^[0-9]+$ ]]; then
    printf 'DNS_OK=0\nTCP_OK=0\nTLS_OK=0\nTLS_VERSION=\nALPN_H2=0\nSAN_MATCH=0\nLATENCY_MS=\n'
    printf 'REASON=invalid_target_format\n'
    return 1
  fi

  if t1c_target_dns_ok "$host"; then dns_ok=1; else dns_ok=0; reason="${reason:-dns_lookup_failed}"; fi
  if t1c_target_tcp_ok "$host" "$port"; then tcp_ok=1; else tcp_ok=0; reason="${reason:-tcp_connect_failed}"; fi
  if t1c_target_tls_ok "$host" "$port"; then tls_ok=1; else tls_ok=0; reason="${reason:-tls_handshake_failed}"; fi
  if [[ "$tls_ok" == "1" ]]; then
    tcp_ok=1
    [[ "$reason" == "tcp_connect_failed" ]] && reason=""
  fi
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

t1c_probe_latency_for_target() {
  local target="$1"
  local line fixture_target fixture_status fixture_latency output latency reason

  if [[ -n "${T1C_PROBE_FIXTURES:-}" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue
      fixture_target="${line%%|*}"
      fixture_status="${line#*|}"
      fixture_status="${fixture_status%%|*}"
      fixture_latency="${line##*|}"
      [[ "$fixture_target" == "$target" ]] || continue
      if [[ "$fixture_status" == "ok" ]]; then
        printf 'LATENCY_MS=%s\n' "$fixture_latency"
        return 0
      fi

      printf 'REASON=%s\n' "$fixture_latency"
      return 1
    done <<<"$T1C_PROBE_FIXTURES"

    printf 'REASON=target_check_failed\n'
    return 1
  fi

  if output="$(bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/check.sh" "$target" 2>/dev/null)"; then
    latency="$(awk -F= '/^LATENCY_MS=/{print $2}' <<<"$output")"
    [[ -n "$latency" ]] || {
      printf 'REASON=missing_latency\n'
      return 1
    }
    printf 'LATENCY_MS=%s\n' "$latency"
    return 0
  fi

  reason="$(awk -F= '/^REASON=/{print $2; exit}' <<<"$output")"
  printf 'REASON=%s\n' "${reason:-target_check_failed}"
  return 1
}

t1c_probe_best_target() {
  local targets_file="$1"
  local line result latency reason best_target="" best_latency="" ok_count=0
  local summaries=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if result="$(t1c_probe_latency_for_target "$line")"; then
      latency="$(awk -F= '/^LATENCY_MS=/{print $2; exit}' <<<"$result")"
      summaries+=("OK ${line} score=$((100000 - latency)) latency=${latency}")
      ok_count=$((ok_count + 1))
      if [[ -z "$best_latency" || "$latency" -lt "$best_latency" ]]; then
        best_target="$line"
        best_latency="$latency"
      fi
    else
      reason="$(awk -F= '/^REASON=/{print $2; exit}' <<<"$result")"
      summaries+=("FAIL ${line} reason=${reason:-target_check_failed}")
    fi
  done < <(t1c_read_target_candidates "$targets_file")

  if [[ -z "$best_target" ]]; then
    printf '%s\n' "${summaries[@]}" >&2
    return 1
  fi

  printf 'BEST_TARGET=%s\n' "$best_target"
  printf 'BEST_SERVER_NAME=%s\n' "$(t1c_target_host "$best_target")"
  printf 'BEST_LATENCY_MS=%s\n' "$best_latency"
  printf 'CANDIDATES_OK=%s\n' "$ok_count"
  printf '%s\n' "${summaries[@]}"
}

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/tests/test_helper.sh"

main() {
  local chinese english english_copy_count chinese_copy_count
  local english_page chinese_page

  english_page="$ROOT_DIR/index.html"
  chinese_page="$ROOT_DIR/zh.html"

  [[ -f "$english_page" ]] || fail "expected index.html to exist"
  [[ -f "$chinese_page" ]] || fail "expected zh.html to exist"

  english="$(cat "$english_page")"
  chinese="$(cat "$chinese_page")"

  assert_match "$english" '<html lang="en">'
  assert_match "$english" '<title>tunnel-1click \| Self-Hosted Xray REALITY VPS Setup</title>'
  assert_match "$english" '<meta name="description" content="Deploy a self-hosted Xray REALITY tunnel on your own VPS with one command\. Includes secure VPS hosting recommendations, install/update commands, and operator docs\.">'
  assert_match "$english" '<link rel="canonical" href="https://0x99\.link/">'
  assert_match "$english" '<link rel="alternate" hreflang="zh-Hans" href="https://0x99\.link/zh\.html">'
  assert_match "$english" '<link rel="alternate" hreflang="x-default" href="https://0x99\.link/">'
  assert_match "$english" '<meta property="og:type" content="website">'
  assert_match "$english" '<meta property="og:url" content="https://0x99\.link/">'
  assert_match "$english" '<meta name="twitter:card" content="summary">'
  assert_match "$english" 'href="zh\.html"[^>]*>中文</a>'
  assert_match "$english" '>Start With a VPS You Control<'
  assert_match "$english" 'self-hosted security starts with infrastructure you can patch'
  assert_match "$english" 'https://bandwagonhost\.com/aff\.php\?aff=79980'
  assert_match "$english" 'https://my\.racknerd\.com/aff\.php\?aff=16609'
  assert_match "$english" 'rel="sponsored noopener"'

  assert_match "$chinese" '<html lang="zh-Hans">'
  assert_match "$chinese" '<title>tunnel-1click \| 自建 Xray REALITY VPS 一键部署</title>'
  assert_match "$chinese" '<meta name="description" content="用一条命令在自己的 VPS 上部署自建 Xray REALITY 隧道。包含安全自建 VPS 推荐、安装/更新命令和运维文档。">'
  assert_match "$chinese" '<link rel="canonical" href="https://0x99\.link/zh\.html">'
  assert_match "$chinese" '<link rel="alternate" hreflang="en" href="https://0x99\.link/">'
  assert_match "$chinese" '<link rel="alternate" hreflang="x-default" href="https://0x99\.link/">'
  assert_match "$chinese" '<meta property="og:locale" content="zh_CN">'
  assert_match "$chinese" 'href="index\.html"[^>]*>English</a>'
  assert_match "$chinese" '>从你控制的 VPS 开始<'
  assert_match "$chinese" '自建安全的第一步'
  assert_match "$chinese" 'https://bandwagonhost\.com/aff\.php\?aff=79980'
  assert_match "$chinese" 'https://my\.racknerd\.com/aff\.php\?aff=16609'
  assert_match "$chinese" 'rel="sponsored noopener"'

  for page_content in "$english" "$chinese"; do
    assert_match "$page_content" 'curl -fsSL https://0x99\.link/install\.sh \| sh'
    assert_match "$page_content" 'curl -fsSL https://0x99\.link/update\.sh \| sh'
    assert_match "$page_content" 'href="README\.md"'
    assert_match "$page_content" 'href="install\.sh"'
    assert_match "$page_content" 'href="update\.sh"'
    assert_match "$page_content" 'systemctl start xray'
    assert_match "$page_content" 'systemctl restart xray'
    assert_match "$page_content" 'journalctl -u xray -n 50 --no-pager'
    assert_match "$page_content" 'tail -n 50 /var/log/xray/error\.log'
    assert_match "$page_content" 'data-copy-target='
    assert_match "$page_content" 'navigator\.clipboard\.writeText'
    assert_match "$page_content" 'Press Ctrl/Cmd\+C'
    assert_not_match "$page_content" 'class="copy-button-text"'
    assert_not_match "$page_content" '>Copy<'
  done

  assert_match "$english" '>What It Sets Up<'
  assert_match "$english" '>Quick Use<'
  assert_match "$english" '>Docs<'
  assert_match "$chinese" '>它会配置什么<'
  assert_match "$chinese" '>快速使用<'
  assert_match "$chinese" '>文档<'

  english_copy_count="$(grep -o 'class="copy-button"' <<< "$english" | wc -l | tr -d ' ')"
  chinese_copy_count="$(grep -o 'class="copy-button"' <<< "$chinese" | wc -l | tr -d ' ')"
  assert_eq "$english_copy_count" "5"
  assert_eq "$chinese_copy_count" "5"
}

main "$@"

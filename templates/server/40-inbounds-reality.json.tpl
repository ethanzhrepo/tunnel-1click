{
  "inbounds": [
    {
      "tag": "dokodemo-in",
      "listen": "127.0.0.1",
      "port": __REALITY_FALLBACK_PORT__,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "__REALITY_TARGET_HOST__",
        "port": __REALITY_TARGET_PORT__,
        "network": "tcp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "tls"
        ],
        "routeOnly": true
      }
    },
    {
      "tag": "vless-reality",
      "listen": "0.0.0.0",
      "port": __XRAY_PORT__,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "__UUID__",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "target": "127.0.0.1:__REALITY_FALLBACK_PORT__",
          "serverNames": [
            "__REALITY_SERVER_NAME__"
          ],
          "privateKey": "__REALITY_PRIVATE_KEY__",
          "shortIds": [
            "__REALITY_SHORT_ID__"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ],
        "routeOnly": true
      }
    }
  ]
}

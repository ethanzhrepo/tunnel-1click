{
  "inbounds": [
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
          "target": "__REALITY_TARGET__",
          "serverNames": [
            "__REALITY_SERVER_NAME__"
          ],
          "privateKey": "__REALITY_PRIVATE_KEY__",
          "shortIds": [
            "__REALITY_SHORT_ID__"
          ],
          "limitFallbackUpload": {
            "afterBytes": 1048576,
            "bytesPerSec": 16384,
            "burstBytesPerSec": 32768
          },
          "limitFallbackDownload": {
            "afterBytes": 1048576,
            "bytesPerSec": 16384,
            "burstBytesPerSec": 32768
          }
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

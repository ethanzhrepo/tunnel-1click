{
  "log": {
    "loglevel": "warning"
  },
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query",
      "https+local://8.8.8.8/dns-query"
    ],
    "queryStrategy": "UseIPv4",
    "useSystemHosts": false
  },
  "inbounds": [
    {
      "tag": "socks-in",
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "udp": false
      }
    },
    {
      "tag": "http-in",
      "listen": "127.0.0.1",
      "port": 10809,
      "protocol": "http",
      "settings": {}
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "__CONNECT_ADDRESS__",
            "port": __XRAY_PORT__,
            "users": [
              {
                "id": "__UUID__",
                "encryption": "none",
                "flow": "xtls-rprx-vision",
                "level": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "sockopt": {
          "domainStrategy": "UseIPv4",
          "tcpKeepAliveIdle": 30,
          "tcpKeepAliveInterval": 15
        },
        "realitySettings": {
          "fingerprint": "__TLS_FINGERPRINT__",
          "serverName": "__REALITY_SERVER_NAME__",
          "publicKey": "__REALITY_PUBLIC_KEY__",
          "shortId": "__REALITY_SHORT_ID__"
        }
      },
      "mux": {
        "enabled": false
      }
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "handshake": 10,
        "connIdle": 3600,
        "uplinkOnly": 5,
        "downlinkOnly": 30
      }
    }
  }
}

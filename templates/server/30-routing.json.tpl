{
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "dokodemo-in"
        ],
        "domain": [
          "__REALITY_SERVER_NAME__"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "inboundTag": [
          "dokodemo-in"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      }
    ]
  }
}

{
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private",
          "geoip:reserved"
        ],
        "outboundTag": "block"
      }
    ]
  }
}

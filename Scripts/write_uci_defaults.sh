#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="./package/base-files/files/etc/uci-defaults/998_custom-net.sh"
mkdir -p "$(dirname "$TARGET_FILE")"

cat > "$TARGET_FILE" <<'EOF'
#!/bin/sh

uci -q set network.lan.proto='static'
uci -q set network.lan.ipaddr='192.168.1.202'
uci -q set network.lan.netmask='255.255.255.0'
uci -q set network.lan.gateway='192.168.1.201'
uci -q delete network.lan.ip6assign
uci -q delete network.lan.delegate

uci -q delete network.lan.dns
uci -q add_list network.lan.dns='223.5.5.5'
uci -q add_list network.lan.dns='223.6.6.6'

uci -q set network.wan.proto='dhcp'
uci -q delete network.wan.username
uci -q delete network.wan.password

uci -q set dhcp.lan.ignore='1'
uci -q set dhcp.lan.ra='disabled'
uci -q set dhcp.lan.dhcpv6='disabled'
uci -q set dhcp.lan.ndp='disabled'
uci -q commit network
uci -q commit dhcp

exit 0
EOF

chmod 0755 "$TARGET_FILE"
echo "created $TARGET_FILE"

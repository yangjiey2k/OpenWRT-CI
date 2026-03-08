#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="./package/base-files/files/etc/uci-defaults/998_custom-net.sh"
mkdir -p "$(dirname "$TARGET_FILE")"

cat > "$TARGET_FILE" <<'EOF'
#!/bin/sh

log() {
  echo "[998_custom-net] $*"
}

uciq() {
  uci -q "$@"
}

log "apply x86 bypass-router defaults"

# 只针对 x86
if ! grep -Eiq "x86|64|86" /etc/openwrt_release 2>/dev/null && ! echo "${WRT_CONFIG:-X86}" | grep -Eiq "x86|64|86"; then
  log "not x86, skip"
  exit 0
fi

# LAN 口固定为旁路由地址
uciq set network.lan.proto='static'
uciq set network.lan.ipaddr='192.168.1.202'
uciq set network.lan.netmask='255.255.255.0'
uciq set network.lan.gateway='192.168.1.201'
uciq delete network.lan.ip6assign
uciq delete network.lan.delegate

# 旁路由自身使用的 DNS
uciq delete network.lan.dns
uciq add_list network.lan.dns='223.5.5.5'
uciq add_list network.lan.dns='223.6.6.6'

# 不使用 PPPoE，不注入拨号账号
uciq set network.wan.proto='dhcp'
uciq delete network.wan.username
uciq delete network.wan.password

# DHCP 交给主路由，旁路由关闭 DHCP/IPv6 RA
uciq set dhcp.lan.ignore='1'
uciq set dhcp.lan.ra='disabled'
uciq set dhcp.lan.dhcpv6='disabled'
uciq set dhcp.lan.ndp='disabled'
uciq delete dhcp.lan.dhcp_option

# 保留 dnsmasq，但不要抢主路由 DHCP
uciq commit network
uciq commit dhcp

# 删除这个项目原来可能注入的端口转发规则
for name in kms rdp dayz_2302 dayz_27016 dayz_2308 router_http router_https openclash_9090 lede_netdata ttyd_7681 esxi_http; do
  sec="$(uci -q show firewall | sed -n "s/^firewall\.\(@redirect\[[0-9]\+\]\)\.name='${name}'$/\1/p" | head -n1)"
  [ -n "$sec" ] && uci -q delete "firewall.${sec}"
done
uciq commit firewall

# 重启相关服务
/etc/init.d/network restart || true
/etc/init.d/dnsmasq restart || true
/etc/init.d/odhcpd restart || true
/etc/init.d/firewall restart || true

log "done"
exit 0
EOF

chmod 0755 "$TARGET_FILE"
echo "✅ [write_uci_defaults] created $TARGET_FILE"

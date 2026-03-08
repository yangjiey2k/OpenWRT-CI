#!/bin/bash
set -euo pipefail

# 移除 luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} \;

# 修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-${WRT_THEME}/g" {} \;

# 修改 immortalwrt.lan 关联 IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/${WRT_IP}/g" {} \;

# 添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ ${WRT_MARK}-${WRT_DATE}')/g" {} \;

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null | head -n1 || true)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -n "${WIFI_SH:-}" ] && [ -f "$WIFI_SH" ]; then
  sed -i "s/BASE_SSID='.*'/BASE_SSID='${WRT_SSID}'/g" "$WIFI_SH"
  sed -i "s/BASE_WORD='.*'/BASE_WORD='${WRT_WORD}'/g" "$WIFI_SH"
elif [ -f "$WIFI_UC" ]; then
  sed -i "s/ssid='.*'/ssid='${WRT_SSID}'/g" "$WIFI_UC"
  sed -i "s/key='.*'/key='${WRT_WORD}'/g" "$WIFI_UC"
  sed -i "s/country='.*'/country='CN'/g" "$WIFI_UC"
  sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" "$WIFI_UC"
fi

CFG_FILE="./package/base-files/files/bin/config_generate"

# 修改默认 IP 地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/${WRT_IP}/g" "$CFG_FILE"

# 修改默认主机名
sed -i "s/hostname='.*'/hostname='${WRT_NAME}'/g" "$CFG_FILE"

# 基础 LuCI
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-${WRT_THEME}=y" >> ./.config

# 不再强制启用 luci-app-argon-config
# echo "CONFIG_PACKAGE_luci-app-${WRT_THEME}-config=y" >> ./.config

# 手动调整的插件
if [ -n "${WRT_PACKAGE:-}" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# 高通平台调整（保留原逻辑，虽然你现在编译 x86 用不到）
DTS_PATH="./target/linux/qualcommax/dts/"

if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  echo "CONFIG_FEED_nss_packages=n" >> ./.config
  echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
  echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
  echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
  echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config

  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi

  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

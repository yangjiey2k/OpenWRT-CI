#!/bin/bash
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
cd "$PKG_PATH"

# 预置 HomeProxy 数据
if [ -d "./homeproxy" ]; then
    echo " "
    HP_RULE="surge"
    HP_PATH="homeproxy/root/etc/homeproxy"

    rm -rf "./$HP_PATH/resources/"*
    git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" "./$HP_RULE/"

    cd "./$HP_RULE/"
    RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*" | head -n1 || true)
    echo "${RES_VER:-0}" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver >/dev/null

    awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
    sed 's/^\.//g' direct.txt > china_list.txt
    sed 's/^\.//g' gfw.txt > gfw_list.txt

    mv -f ./{china_*,gfw_list}.{ver,txt} "../$HP_PATH/resources/"
    cd "$PKG_PATH"
    rm -rf "./$HP_RULE/"
    echo "✅ homeproxy data updated!"
fi

# 预置 OpenClash Smart Core 和数据
if [ -d "./OpenClash" ]; then
    echo " "
    CORE_TYPE=$(echo "$WRT_CONFIG" | grep -Eiq "64|86" && echo "amd64" || echo "arm64")

    OWNER="vernesong"
    REPO="mihomo"
    FILE_PATTERN="mihomo-linux-${CORE_TYPE}-alpha-smart.*\\.gz"

    echo "Retrieving the latest pre-release version information for OpenClash Smart Core..."
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases?per_page=5")
    ASSET_URL=$(echo "$RELEASE_JSON" | jq -r --arg pattern "$FILE_PATTERN" \
        '.[] | select(.prerelease == true) | .assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n1)

    if [ -z "${ASSET_URL:-}" ] || [ "$ASSET_URL" = "null" ]; then
        echo "No matching pre-release resource file found."
        exit 0
    fi

    FILENAME=$(basename "$ASSET_URL")
    echo "✅ Found Smart Core: $ASSET_URL"

    LATEST_MMDBURL=$(curl -s "https://api.github.com/repos/alecthw/mmdb_china_ip_list/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*Country\.mmdb"' | \
        cut -d'"' -f4)

    [ -n "${LATEST_MMDBURL:-}" ] || { echo "No matching Country.mmdb found."; exit 0; }

    LATEST_GEOURL=$(curl -s "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | \
        grep -o '"browser_download_url": *"[^"]*geosite\.dat"' | \
        cut -d'"' -f4)

    [ -n "${LATEST_GEOURL:-}" ] || { echo "No matching geosite.dat found."; exit 0; }

    cd "./OpenClash/luci-app-openclash/root/etc/openclash/"
    curl -sL -o Model.bin "https://github.com/vernesong/mihomo/releases/download/LightGBM-Model/Model.bin"
    curl -sL -o Country.mmdb "$LATEST_MMDBURL"
    curl -sL -o GeoSite.dat "$LATEST_GEOURL"

    mkdir -p ./core/
    cd ./core/
    curl -sL -o "$FILENAME" "$ASSET_URL"
    gunzip -c "$FILENAME" > clash_meta
    chmod +x clash_meta
    rm -f "$FILENAME"

    cd "$PKG_PATH"
    echo "✅ OpenClash smart core, Model and data updated!"
fi

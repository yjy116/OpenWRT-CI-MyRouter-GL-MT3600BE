#!/usr/bin/env bash
set -e

# 默认 IP
sed -i 's/192.168.1.1/192.168.8.1/g' package/base-files/files/bin/config_generate || true

# 默认主机名
sed -i "s/hostname='OpenWrt'/hostname='MT3600BE'/g" package/base-files/files/bin/config_generate || true

# 默认主题（存在时）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile || true

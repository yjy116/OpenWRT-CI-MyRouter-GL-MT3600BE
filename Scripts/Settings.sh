#!/usr/bin/env bash
set -e

echo "==> 加载自定义配置"

# 写入默认IP（可改）
sed -i 's/192.168.1.1/192.168.8.1/g' package/base-files/files/bin/config_generate

# 设置主机名
sed -i "s/hostname='.*'/hostname='MT3600BE-LEDE'/g" package/base-files/files/bin/config_generate || true

echo "==> 自定义设置完成"

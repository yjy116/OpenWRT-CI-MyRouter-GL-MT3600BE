#!/bin/bash

# 1. 修改默认 IP 为 192.168.18.1
sed -i 's/192.168.1.1/192.168.18.1/g' package/base-files/files/bin/config_generate

# 2. 修改默认主机名为 Beryl7-Immortal
sed -i 's/OpenWrt/Beryl7-Immortal/g' package/base-files/files/bin/config_generate

# 3. 设置默认主题为 Argon
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 4. 强制删除无线配置 (确保开机重新探测 2.4G 和 5G)
rm -f package/base-files/files/etc/config/wireless

# 5. 设置 root 默认密码为 password (采用覆盖式注入，规避 sed 匹配失败)
# 这一行直接创建或覆盖 shadow 文件，确保密码一定是 password
mkdir -p package/base-files/files/etc/
echo 'root:$1$V4UetPzk$CY6Sv6wSRCosSKqvePqgr0:18856:0:99999:7:::' > package/base-files/files/etc/shadow

# 6. 开启 MTK WED 硬件转发加速
echo "CONFIG_NET_MEDIATEK_SOC_WED=y" >> .config

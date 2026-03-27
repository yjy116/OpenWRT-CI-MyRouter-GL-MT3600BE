#!/bin/bash
# 添加常用的第三方插件源
sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '$a src-git small https://github.com/kenzok8/small' feeds.conf.default

# 强制同步最新版 HomeProxy (针对 ImmortalWrt 环境优化)
rm -rf package/feeds/luci/luci-app-homeproxy
git clone https://github.com/immortalwrt/homeproxy package/homeproxy

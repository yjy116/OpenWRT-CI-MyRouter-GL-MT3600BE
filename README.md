# OpenWRT-CI-MyRouter-GL-MT3600BE

这个项目已经整理成“尽量只改 `Config/GENERAL.txt`”的模式。

## 日常维护方式

- 官方 `ImmortalWrt` feed 里的插件：通常只需要修改 [GENERAL.txt](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Config/GENERAL.txt) 里的 `CONFIG_PACKAGE_*` 行。
- 第三方插件：也优先在 [GENERAL.txt](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Config/GENERAL.txt) 里维护。
  `Scripts/Packages.sh` 会读取 `GENERAL.txt` 里的 `@vendor` 规则，自动拉取仓库并注入包目录。

## 目前已支持只改 GENERAL.txt 的第三方插件

- `luci-app-openclash`
- `luci-app-homeproxy`
- `luci-app-fancontrol`
- `luci-app-disks-info`
- `luci-app-temp-status`
- `luci-app-mosdns`

## 规则说明

- 对于官方 feed 包，只改 `CONFIG_PACKAGE_*` 行就可以。
- 对于上面这些第三方插件，只需要在 [GENERAL.txt](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Config/GENERAL.txt) 里保留或删除对应的：
  - `# @vendor ...` 规则
  - `CONFIG_PACKAGE_*` 行
- `Samba4` 属于官方 feed，所以它本来就只需要改 [GENERAL.txt](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Config/GENERAL.txt)。

## 边界说明

- 如果以后新增的是“普通结构”的第三方插件，一般也只需要在 [GENERAL.txt](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Config/GENERAL.txt) 增加一条 `@vendor` 规则和对应 `CONFIG_PACKAGE_*` 行。
- 只有当某个新插件需要特殊预处理逻辑时，才可能需要再扩展 [Packages.sh](C:/Users/yjy11/Documents/Codex/projects/MT3600BE/OpenWRT-CI-MyRouter-GL-MT3600BE/Scripts/Packages.sh)。

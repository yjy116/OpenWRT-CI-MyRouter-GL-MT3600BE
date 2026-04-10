#!/bin/sh

set -eu

OUT="/tmp/mt3600be-stock-info-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "## Timestamp"
  date
  echo

  echo "## Kernel"
  uname -a
  echo

  echo "## OpenWrt Release"
  cat /etc/openwrt_release 2>/dev/null || true
  echo

  echo "## Board"
  ubus call system board 2>/dev/null || true
  echo

  echo "## Sysinfo"
  cat /tmp/sysinfo/board_name 2>/dev/null || true
  printf '\n'
  tr -d '\000' </proc/device-tree/model 2>/dev/null || true
  printf '\n'
  tr -d '\000' </proc/device-tree/compatible 2>/dev/null || true
  printf '\n\n'

  echo "## MTD"
  cat /proc/mtd 2>/dev/null || true
  echo

  echo "## Block Info"
  block info 2>/dev/null || true
  echo

  echo "## Network"
  ip -br link 2>/dev/null || ip link 2>/dev/null || true
  echo

  echo "## Installed Packages"
  opkg list-installed 2>/dev/null | grep -Ei 'gl-|luci|mt|wifi|vpn|wireguard|openvpn' || true
  echo

  echo "## Bootloader Environment"
  fw_printenv 2>/dev/null || true
  echo

  echo "## Filtered Dmesg"
  dmesg 2>/dev/null | grep -Ei 'mtd|ubi|spi|nand|factory|mt76|mt79|mt798|mt799|phy|2p5g' || true
} >"${OUT}"

echo "Saved to ${OUT}"

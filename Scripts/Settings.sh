#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/Config}"
WRT_CONFIG="${WRT_CONFIG:-MT3600BE}"
WRT_CONFIG_FILE="${WRT_CONFIG_FILE:-${CONFIG_DIR}/${WRT_CONFIG}.txt}"
GENERAL_CONFIG_FILE="${GENERAL_CONFIG_FILE:-${CONFIG_DIR}/GENERAL.txt}"
WORK_ROOT="${WORK_ROOT:-$HOME/work}"
BUILD_ROOT="${BUILD_ROOT:-${WORK_ROOT}/immortalwrt-${WRT_CONFIG,,}}"
DEVICE_NAME="${DEVICE_NAME:-glinet_gl-mt3600be}"
DEVICE_DTS="${DEVICE_DTS:-mt7987a-glinet-gl-mt3600be}"
REQUIRED_CONFIG_SYMBOLS=(
  "CONFIG_PACKAGE_luci=y"
  "CONFIG_PACKAGE_default-settings-chn=y"
  "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y"
)

is_windows_mount_path() {
  local path="$1"
  [[ "${path}" =~ ^/mnt/[A-Za-z](/|$) ]]
}

validate_host_environment() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "This script must run inside Linux or WSL2."
    exit 1
  fi

  if is_windows_mount_path "${PWD}" || is_windows_mount_path "${PROJECT_ROOT}" || is_windows_mount_path "${WORK_ROOT}" || is_windows_mount_path "${BUILD_ROOT}"; then
    cat <<'EOF'
Do not build OpenWrt/ImmortalWrt from a Windows-mounted path such as /mnt/c.
Use a native Linux path like:
  export WORK_ROOT=$HOME/work
EOF
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Run Scripts/bootstrap-ubuntu.sh first."
    exit 1
  fi

  if ! command -v make >/dev/null 2>&1; then
    echo "make is required. Run Scripts/bootstrap-ubuntu.sh first."
    exit 1
  fi

  if [[ ! -f "${WRT_CONFIG_FILE}" ]]; then
    echo "Device config not found: ${WRT_CONFIG_FILE}"
    exit 1
  fi

  if [[ ! -f "${GENERAL_CONFIG_FILE}" ]]; then
    echo "General config not found: ${GENERAL_CONFIG_FILE}"
    exit 1
  fi
}

validate_device_support() {
  if ! grep -Rqs "define Device/${DEVICE_NAME}" target/linux/mediatek/image/filogic.mk; then
    echo "Device profile ${DEVICE_NAME} was not found."
    exit 2
  fi

  if [[ ! -f "target/linux/mediatek/dts/${DEVICE_DTS}.dts" ]]; then
    echo "Device DTS ${DEVICE_DTS}.dts was not found."
    exit 2
  fi
}

validate_required_config_symbols() {
  local missing=()
  local symbol

  for symbol in "${REQUIRED_CONFIG_SYMBOLS[@]}"; do
    if ! grep -q "^${symbol}$" .config; then
      missing+=("${symbol}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "WARNING: Required LuCI/i18n config symbols are missing after defconfig:"
    printf '  %s\n' "${missing[@]}"
    echo "The build will continue, but the resulting firmware may not offer Chinese in LuCI."
  fi
}

apply_config_fragments() {
  cat "${WRT_CONFIG_FILE}" "${GENERAL_CONFIG_FILE}" > .config

  if [[ -n "${EXTRA_CONFIG_FILE:-}" && -f "${EXTRA_CONFIG_FILE}" ]]; then
    cat "${EXTRA_CONFIG_FILE}" >> .config
  fi

  make defconfig

  if [[ "${RUN_MENUCONFIG:-0}" == "1" ]]; then
    make menuconfig
  fi

  validate_required_config_symbols
}

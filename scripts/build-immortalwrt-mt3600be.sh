#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_URL="${REPO_URL:-https://github.com/immortalwrt/immortalwrt.git}"
REPO_BRANCH="${REPO_BRANCH:-master}"
WORK_ROOT="${WORK_ROOT:-$HOME/work}"
BUILD_ROOT="${BUILD_ROOT:-$WORK_ROOT/immortalwrt-mt3600be}"
VENDOR_ROOT="${VENDOR_ROOT:-$WORK_ROOT/immortalwrt-vendor}"
DEVICE_NAME="${DEVICE_NAME:-glinet_gl-mt3600be}"
DEVICE_DTS="${DEVICE_DTS:-mt7987a-glinet-gl-mt3600be}"
SEED_CONFIG="${SEED_CONFIG:-${PROJECT_ROOT}/configs/mt3600be.seed}"
JOBS="${JOBS:-$(nproc)}"
OPENCLASH_REPO_URL="${OPENCLASH_REPO_URL:-https://github.com/vernesong/OpenClash.git}"
OPENCLASH_REPO_BRANCH="${OPENCLASH_REPO_BRANCH:-master}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script must run inside Linux or WSL2."
  exit 1
fi

if [[ "${PWD}" == /mnt/* ]] || [[ "${WORK_ROOT}" == /mnt/* ]] || [[ "${BUILD_ROOT}" == /mnt/* ]]; then
  cat <<'EOF'
Do not build OpenWrt/ImmortalWrt from a Windows-mounted path such as /mnt/c.
Use a native Linux path like:
  export WORK_ROOT=$HOME/work
EOF
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required. Run scripts/bootstrap-ubuntu.sh first."
  exit 1
fi

if ! command -v make >/dev/null 2>&1; then
  echo "make is required. Run scripts/bootstrap-ubuntu.sh first."
  exit 1
fi

if [[ ! -f "${SEED_CONFIG}" ]]; then
  echo "Seed config not found: ${SEED_CONFIG}"
  exit 1
fi

sync_git_repo() {
  local repo_url="$1"
  local repo_branch="$2"
  local repo_dir="$3"

  if [[ ! -d "${repo_dir}/.git" ]]; then
    git clone --single-branch --branch "${repo_branch}" "${repo_url}" "${repo_dir}"
    return
  fi

  git -C "${repo_dir}" fetch origin "${repo_branch}" --depth 1
  git -C "${repo_dir}" checkout "${repo_branch}"
  git -C "${repo_dir}" reset --hard "origin/${repo_branch}"
}

prepare_custom_packages() {
  local openclash_src="${VENDOR_ROOT}/OpenClash"
  local openclash_po2lmo_bin

  mkdir -p "${VENDOR_ROOT}"

  sync_git_repo "${OPENCLASH_REPO_URL}" "${OPENCLASH_REPO_BRANCH}" "${openclash_src}"
  rm -rf "${BUILD_ROOT}/package/luci-app-openclash"

  cp -a "${openclash_src}/luci-app-openclash" "${BUILD_ROOT}/package/luci-app-openclash"

  make -C "${openclash_src}/tools/po2lmo"
  openclash_po2lmo_bin="${openclash_src}/tools/po2lmo/src"
  export PATH="${openclash_po2lmo_bin}:${PATH}"
}

mkdir -p "${WORK_ROOT}"

if [[ ! -d "${BUILD_ROOT}/.git" ]]; then
  git clone --single-branch --branch "${REPO_BRANCH}" "${REPO_URL}" "${BUILD_ROOT}"
else
  cd "${BUILD_ROOT}"
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Existing build tree is dirty: ${BUILD_ROOT}"
    echo "Please commit/stash/remove local changes before updating it."
    exit 1
  fi
  git fetch origin "${REPO_BRANCH}" --depth 1
  git checkout "${REPO_BRANCH}"
  git pull --ff-only origin "${REPO_BRANCH}"
fi

cd "${BUILD_ROOT}"

./scripts/feeds update -a
prepare_custom_packages
./scripts/feeds install -a

if ! grep -Rqs "define Device/${DEVICE_NAME}" target/linux/mediatek/image/filogic.mk; then
  echo "Device profile ${DEVICE_NAME} was not found in ${REPO_BRANCH}."
  echo "That usually means the selected branch no longer contains this target."
  exit 2
fi

if [[ ! -f "target/linux/mediatek/dts/${DEVICE_DTS}.dts" ]]; then
  echo "Device DTS ${DEVICE_DTS}.dts was not found."
  exit 2
fi

cp "${SEED_CONFIG}" .config
make defconfig

if [[ "${RUN_MENUCONFIG:-0}" == "1" ]]; then
  make menuconfig
fi

make download -j"${JOBS}"
make -j"${JOBS}" V=s

cat <<EOF

Build finished.

Expected output directory:
  ${BUILD_ROOT}/bin/targets/mediatek/filogic/

Recommended next checks:
  ls -lh ${BUILD_ROOT}/bin/targets/mediatek/filogic/
  sha256sum ${BUILD_ROOT}/bin/targets/mediatek/filogic/*
EOF

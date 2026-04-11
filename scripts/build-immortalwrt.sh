#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_URL="${REPO_URL:-https://github.com/immortalwrt/immortalwrt.git}"
REPO_BRANCH="${REPO_BRANCH:-master}"
WRT_CONFIG="${WRT_CONFIG:-MT3600BE}"
WORK_ROOT="${WORK_ROOT:-$HOME/work}"
BUILD_ROOT="${BUILD_ROOT:-${WORK_ROOT}/immortalwrt-${WRT_CONFIG,,}}"
VENDOR_ROOT="${VENDOR_ROOT:-${WORK_ROOT}/immortalwrt-vendor}"
CACHE_ROOT="${CACHE_ROOT:-${WORK_ROOT}/cache}"
DL_DIR="${DL_DIR:-${CACHE_ROOT}/dl}"
CCACHE_DIR="${CCACHE_DIR:-${CACHE_ROOT}/ccache}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-2G}"
DEVICE_NAME="${DEVICE_NAME:-glinet_gl-mt3600be}"
DEVICE_DTS="${DEVICE_DTS:-mt7987a-glinet-gl-mt3600be}"
JOBS="${JOBS:-$(nproc)}"
TEST_ONLY="${TEST_ONLY:-0}"
BUILD_VERBOSE="${BUILD_VERBOSE:-0}"
BUILD_MODE="${1:-build}"

source "${PROJECT_ROOT}/Scripts/Settings.sh"
source "${PROJECT_ROOT}/Scripts/Packages.sh"

prepare_build_tree() {
  mkdir -p "${WORK_ROOT}"

  if [[ ! -d "${BUILD_ROOT}/.git" ]]; then
    git clone --single-branch --branch "${REPO_BRANCH}" "${REPO_URL}" "${BUILD_ROOT}"
    return
  fi

  cd "${BUILD_ROOT}"
  git remote set-url origin "${REPO_URL}"

  if ! git diff --quiet --ignore-submodules HEAD -- || ! git diff --cached --quiet --ignore-submodules --; then
    echo "Existing build tree is dirty: ${BUILD_ROOT}"
    echo "Please commit/stash tracked source changes before updating it."
    exit 1
  fi

  git fetch origin "${REPO_BRANCH}" --depth 1
  git checkout -B "${REPO_BRANCH}" "origin/${REPO_BRANCH}"
}

prepare_shared_cache_dirs() {
  mkdir -p "${DL_DIR}" "${CCACHE_DIR}"

  if [[ -e "${BUILD_ROOT}/dl" && ! -L "${BUILD_ROOT}/dl" ]]; then
    rm -rf "${BUILD_ROOT}/dl"
  fi

  ln -sfn "${DL_DIR}" "${BUILD_ROOT}/dl"

  export CCACHE_DIR
  export CCACHE_BASEDIR="${BUILD_ROOT}"
  export CCACHE_COMPILERCHECK="${CCACHE_COMPILERCHECK:-content}"

  if command -v ccache >/dev/null 2>&1; then
    ccache -M "${CCACHE_MAXSIZE}" >/dev/null 2>&1 || true
    echo "ccache stats before build:"
    ccache -s || true
  fi
}

refresh_cached_host_tool_stamps() {
  local stamp_dir
  local refreshed=0

  while IFS= read -r -d '' stamp_dir; do
    case "${stamp_dir}" in
      "${BUILD_ROOT}"/staging_dir/host/stamp|\
      "${BUILD_ROOT}"/staging_dir/hostpkg/stamp|\
      "${BUILD_ROOT}"/staging_dir/toolchain-*/stamp)
        find "${stamp_dir}" -type f -exec touch {} + 2>/dev/null || true
        refreshed=1
        ;;
    esac
  done < <(find "${BUILD_ROOT}/staging_dir" -type d -name stamp -print0 2>/dev/null)

  if [[ "${refreshed}" == "1" ]]; then
    mkdir -p "${BUILD_ROOT}/tmp"
    : > "${BUILD_ROOT}/tmp/.build"
    echo "Refreshed restored host/toolchain cache stamps."
  fi
}

prepare_build_workspace() {
  prepare_build_tree
  cd "${BUILD_ROOT}"
  prepare_shared_cache_dirs
}

prepare_feeds_and_config() {
  ./scripts/feeds update -a
  prepare_custom_packages
  ./scripts/feeds install -a

  validate_device_support
  apply_config_fragments
  refresh_cached_host_tool_stamps
}

run_make() {
  if [[ "${BUILD_VERBOSE}" == "1" ]]; then
    make -j"${JOBS}" V=s "$@"
  else
    make -j"${JOBS}" "$@"
  fi
}

run_test_only_notice() {
  cat <<EOF

Test-only mode finished.

Generated config:
  ${BUILD_ROOT}/.config
EOF
}

run_build_complete_notice() {
  cat <<EOF

Build finished.

Expected output directory:
  ${BUILD_ROOT}/bin/targets/mediatek/filogic/

Recommended next checks:
  ls -lh ${BUILD_ROOT}/bin/targets/mediatek/filogic/
  sha256sum ${BUILD_ROOT}/bin/targets/mediatek/filogic/*
EOF
}

run_prewarm_complete_notice() {
  cat <<EOF

Host/toolchain prewarm finished.

Prepared cache directories:
  ${BUILD_ROOT}/staging_dir/host
  ${BUILD_ROOT}/staging_dir/hostpkg
EOF
}

main() {
  validate_host_environment
  case "${BUILD_MODE}" in
    prepare-tree)
      prepare_build_tree
      ;;
    prewarm-host-tool)
      prepare_build_workspace
      prepare_feeds_and_config
      run_make tools/install toolchain/install
      run_prewarm_complete_notice
      ;;
    build)
      prepare_build_workspace
      prepare_feeds_and_config

      if [[ "${TEST_ONLY}" == "1" ]]; then
        run_test_only_notice
        exit 0
      fi

      make download -j"${JOBS}"
      find dl -type f -size -1024c -delete

      run_make

      if command -v ccache >/dev/null 2>&1; then
        echo "ccache stats after build:"
        ccache -s || true
      fi

      run_build_complete_notice
      ;;
    *)
      echo "Usage: $0 [build|prepare-tree|prewarm-host-tool]"
      exit 1
      ;;
  esac
}

main "$@"

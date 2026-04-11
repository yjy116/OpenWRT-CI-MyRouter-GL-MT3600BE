#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/Config}"
GENERAL_CONFIG_FILE="${GENERAL_CONFIG_FILE:-${CONFIG_DIR}/GENERAL.txt}"
WORK_ROOT="${WORK_ROOT:-$HOME/work}"
WRT_CONFIG="${WRT_CONFIG:-MT3600BE}"
BUILD_ROOT="${BUILD_ROOT:-${WORK_ROOT}/immortalwrt-${WRT_CONFIG,,}}"
VENDOR_ROOT="${VENDOR_ROOT:-${WORK_ROOT}/immortalwrt-vendor}"

config_package_enabled() {
  local package_name="$1"
  [[ -f "${GENERAL_CONFIG_FILE}" ]] && grep -Eq "^CONFIG_PACKAGE_${package_name}=y$" "${GENERAL_CONFIG_FILE}"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

sync_git_repo() {
  local repo_url="$1"
  local repo_branch="$2"
  local repo_dir="$3"

  if [[ ! -d "${repo_dir}/.git" ]]; then
    git clone --single-branch --branch "${repo_branch}" "${repo_url}" "${repo_dir}"
    return
  fi

  git -C "${repo_dir}" remote set-url origin "${repo_url}"

  if ! git -C "${repo_dir}" diff --quiet --ignore-submodules HEAD -- || ! git -C "${repo_dir}" diff --cached --quiet --ignore-submodules --; then
    echo "Vendor repo is dirty: ${repo_dir}"
    echo "Please clean tracked source changes before updating."
    exit 1
  fi

  git -C "${repo_dir}" fetch origin "${repo_branch}" --depth 1
  git -C "${repo_dir}" checkout -B "${repo_branch}" "origin/${repo_branch}"
}

copy_package_dir() {
  local src_dir="$1"
  local dst_dir="$2"

  if [[ ! -d "${src_dir}" ]]; then
    echo "Package directory was not found: ${src_dir}"
    exit 1
  fi

  rm -rf "${dst_dir}"
  mkdir -p "${dst_dir}"
  cp -a "${src_dir}/." "${dst_dir}/"
  rm -rf "${dst_dir}/.git"
}

run_vendor_hook() {
  local repo_dir="$1"
  local hook="${2:-}"
  local openclash_po2lmo_dir
  local openclash_po2lmo_bin

  case "${hook}" in
    ""|none)
      ;;
    po2lmo)
      if command -v po2lmo >/dev/null 2>&1; then
        return
      fi

      openclash_po2lmo_dir="${repo_dir}/luci-app-openclash/tools/po2lmo"
      if [[ ! -d "${openclash_po2lmo_dir}" ]]; then
        echo "OpenClash po2lmo directory was not found: ${openclash_po2lmo_dir}"
        exit 1
      fi

      make -C "${openclash_po2lmo_dir}"
      openclash_po2lmo_bin="${openclash_po2lmo_dir}/src"
      export PATH="${openclash_po2lmo_bin}:${PATH}"
      ;;
    *)
      echo "Unknown vendor hook: ${hook}"
      exit 1
      ;;
  esac
}

copy_vendor_specs() {
  local repo_dir="$1"
  local copy_specs="$2"
  local spec src_rel dst_rel src_dir dst_dir

  IFS=';' read -r -a specs <<< "${copy_specs}"
  for spec in "${specs[@]}"; do
    spec="$(trim_whitespace "${spec}")"
    [[ -n "${spec}" ]] || continue

    if [[ "${spec}" != *:* ]]; then
      echo "Invalid vendor copy spec: ${spec}"
      exit 1
    fi

    src_rel="$(trim_whitespace "${spec%%:*}")"
    dst_rel="$(trim_whitespace "${spec#*:}")"

    if [[ "${src_rel}" == "." ]]; then
      src_dir="${repo_dir}"
    else
      src_dir="${repo_dir}/${src_rel}"
    fi

    dst_dir="${BUILD_ROOT}/${dst_rel}"
    copy_package_dir "${src_dir}" "${dst_dir}"
  done
}

prepare_custom_packages() {
  local line package_name repo_url repo_branch copy_specs hook repo_dir

  mkdir -p "${VENDOR_ROOT}"

  while IFS= read -r line; do
    if [[ ! "${line}" =~ ^#[[:space:]]*@vendor[[:space:]]+([^|]+)\|([^|]+)\|([^|]+)\|([^|]+)(\|(.*))?$ ]]; then
      continue
    fi

    package_name="$(trim_whitespace "${BASH_REMATCH[1]}")"
    repo_url="$(trim_whitespace "${BASH_REMATCH[2]}")"
    repo_branch="$(trim_whitespace "${BASH_REMATCH[3]}")"
    copy_specs="$(trim_whitespace "${BASH_REMATCH[4]}")"
    hook="$(trim_whitespace "${BASH_REMATCH[6]:-}")"

    if ! config_package_enabled "${package_name}"; then
      continue
    fi

    repo_dir="${VENDOR_ROOT}/${package_name}"
    sync_git_repo "${repo_url}" "${repo_branch}" "${repo_dir}"
    copy_vendor_specs "${repo_dir}" "${copy_specs}"
    run_vendor_hook "${repo_dir}" "${hook}"
  done < "${GENERAL_CONFIG_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    prepare)
      prepare_custom_packages
      ;;
    *)
      echo "Usage: $0 prepare"
      exit 1
      ;;
  esac
fi

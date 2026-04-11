#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
WORK_ROOT="${WORK_ROOT:-$HOME/work}"
WRT_CONFIG="${WRT_CONFIG:-MT3600BE}"
BUILD_ROOT="${BUILD_ROOT:-${WORK_ROOT}/immortalwrt-${WRT_CONFIG,,}}"
RUNNER_TEMP="${RUNNER_TEMP:-${PROJECT_ROOT}/.tmp}"
TARGET_DIR="${TARGET_DIR:-${BUILD_ROOT}/bin/targets/mediatek/filogic}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${RUNNER_TEMP}/mt3600be-artifacts}"
WRT_NAME="${WRT_NAME:-GL-MT3600BE}"
WRT_DEVICE_LABEL="${WRT_DEVICE_LABEL:-GL.iNet GL-MT3600BE}"
REPO_BRANCH="${REPO_BRANCH:-master}"
RELEASE_TAG_PREFIX="${RELEASE_TAG_PREFIX:-mt3600be}"
TEST_ONLY="${TEST_ONLY:-0}"

collect_artifacts() {
  local file
  local files=()

  mkdir -p "${ARTIFACT_DIR}"

  files+=("${RUNNER_TEMP}/build.log")

  if [[ -f "${BUILD_ROOT}/.config" ]]; then
    cp -v "${BUILD_ROOT}/.config" "${ARTIFACT_DIR}/${WRT_CONFIG}.config"
  fi

  if [[ "${TEST_ONLY}" != "1" ]]; then
    files+=(
      "${TARGET_DIR}"/*sysupgrade*.bin
      "${TARGET_DIR}"/*.bin
      "${TARGET_DIR}"/*.itb
      "${TARGET_DIR}"/*.buildinfo
      "${TARGET_DIR}"/*.json
      "${TARGET_DIR}"/*.manifest
    )
  fi

  for file in "${files[@]}"; do
    if [[ -f "${file}" ]]; then
      cp -v "${file}" "${ARTIFACT_DIR}/"
    fi
  done

  if ! find "${ARTIFACT_DIR}" -maxdepth 1 -type f | grep -q .; then
    echo "No artifacts were collected."
    exit 1
  fi

  (
    cd "${ARTIFACT_DIR}"
    local copied=(*)
    if [[ ${#copied[@]} -gt 0 ]]; then
      sha256sum "${copied[@]}" > SHA256SUMS
    fi
    ls -lh
  )
}

prepare_release_metadata() {
  local branch_slug
  local build_commit
  local build_time
  local tag
  local title
  local notes_file

  branch_slug="$(printf '%s' "${REPO_BRANCH}" | tr '/ ' '--' | tr -cd '[:alnum:]._-')"
  build_commit="$(git -C "${BUILD_ROOT}" rev-parse --short=12 HEAD)"
  build_time="$(date -u +'%Y%m%d-%H%M%S')"
  tag="${RELEASE_TAG_PREFIX}-${branch_slug}-${build_time}-run${GITHUB_RUN_NUMBER:-local}"
  title="${WRT_DEVICE_LABEL} ImmortalWrt ${branch_slug} ${build_time}"
  notes_file="${RUNNER_TEMP}/release-notes.md"

  {
    echo "# ${WRT_DEVICE_LABEL} automated build"
    echo
    echo "- Config: \`${WRT_CONFIG}\`"
    echo "- Branch: \`${REPO_BRANCH}\`"
    echo "- Commit: \`${build_commit}\`"
    if [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
      echo "- Workflow run: [#${GITHUB_RUN_NUMBER}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
    fi
    echo "- Trigger event: \`${GITHUB_EVENT_NAME:-manual}\`"
    echo
    echo "Firmware files and checksums are attached below."
  } > "${notes_file}"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "tag=${tag}"
      echo "title=${title}"
      echo "notes_file=${notes_file}"
    } >> "${GITHUB_OUTPUT}"
  else
    echo "tag=${tag}"
    echo "title=${title}"
    echo "notes_file=${notes_file}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    collect-artifacts)
      collect_artifacts
      ;;
    prepare-release-metadata)
      prepare_release_metadata
      ;;
    *)
      echo "Usage: $0 collect-artifacts|prepare-release-metadata"
      exit 1
      ;;
  esac
fi

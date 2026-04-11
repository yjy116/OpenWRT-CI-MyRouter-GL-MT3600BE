#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This bootstrap script must run inside Linux or WSL2."
  exit 1
fi

bootstrap_url="${BOOTSTRAP_URL:-https://build-scripts.immortalwrt.org/init_build_environment.sh}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to download the official ImmortalWrt bootstrap script."
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  bash <(curl -fsSL "${bootstrap_url}")
  exit 0
fi

if command -v sudo >/dev/null 2>&1; then
  curl -fsSL "${bootstrap_url}" | sudo bash
  exit 0
fi

echo "Please run this script as root or install sudo first."
exit 1

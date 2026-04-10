#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script must run inside Linux or WSL2."
  exit 1
fi

if [[ "${PWD}" == /mnt/* ]]; then
  cat <<'EOF'
Build scripts should not run from /mnt/c or another Windows-mounted path.
Please copy this project into a native Linux path first, for example:
  mkdir -p ~/work
  cp -r /mnt/c/Users/yjy11/Documents/Codex/projects/MT3600BE ~/work/
EOF
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required."
  exit 1
fi

sudo apt update
sudo apt install -y \
  bash \
  bc \
  build-essential \
  bzip2 \
  ca-certificates \
  clang \
  curl \
  file \
  flex \
  g++ \
  g++-multilib \
  gawk \
  gcc-multilib \
  gettext \
  git \
  libncurses5-dev \
  libssl-dev \
  patch \
  python3 \
  python3-setuptools \
  qemu-utils \
  rsync \
  subversion \
  swig \
  tar \
  unzip \
  wget \
  xsltproc \
  zlib1g-dev

cat <<'EOF'
Dependencies installed.

Next step:
  bash scripts/build-immortalwrt-mt3600be.sh
EOF

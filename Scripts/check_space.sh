#!/usr/bin/env bash
set -e
echo "========== Disk space =========="
df -h
echo "========== Memory =========="
free -h || true

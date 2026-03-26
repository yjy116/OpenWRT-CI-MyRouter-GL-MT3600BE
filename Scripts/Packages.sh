#!/usr/bin/env bash
set -e

# Add a lightweight theme feed only.
grep -q "kenzok8" feeds.conf.default || echo "src-git argon https://github.com/jerrykuku/luci-theme-argon.git" >> feeds.conf.default

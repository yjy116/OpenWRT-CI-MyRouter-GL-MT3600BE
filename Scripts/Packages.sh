#!/usr/bin/env bash
set -e

# Keep master-tracking builds conservative.
# Do not add third-party feeds here by default.
# Recent argon metadata caused feed index generation failures,
# so this script intentionally uses upstream feeds only.

echo "Using upstream feeds only for master auto-fix build."

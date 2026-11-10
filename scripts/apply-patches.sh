#!/usr/bin/env bash
# Applies patches/*.patch to the Luma-Framework submodule's working tree (not as commits, so the
# submodule stays at its pinned upstream commit). Safe to run again: already applied patches are skipped.
set -euo pipefail
cd "$(dirname "$0")/.."

for patch in patches/*.patch; do
  if git -C Luma-Framework apply --reverse --check "../$patch" 2>/dev/null; then
    echo "already applied: $patch"
  else
    git -C Luma-Framework apply "../$patch"
    echo "applied: $patch"
  fi
done

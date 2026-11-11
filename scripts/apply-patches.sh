#!/usr/bin/env bash
# Applies patches/*.patch to the Luma-Framework submodule's working tree (not as commits, so the
# submodule stays at its pinned upstream commit). Safe to run again: already applied patches are skipped.
set -euo pipefail
cd "$(dirname "$0")/.."

patches=()
for patch in patches/*.patch; do
  patches+=("$PWD/$patch")
done
count=${#patches[@]}

# The patches change the same lines, so they can only be checked as a series: one alone doesn't
# reverse on a tree where later patches are applied too, and "git apply --check" checks each patch
# against the unmodified tree rather than chaining them. So they are really applied, to a snapshot
# of the working tree in a temporary index, to find the applied prefix (the first k patches
# reverse, last first) after which the remaining patches apply.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
snapshot="$tmp/snapshot"
GIT_INDEX_FILE="$snapshot" git -C Luma-Framework read-tree HEAD
GIT_INDEX_FILE="$snapshot" git -C Luma-Framework add -A

for ((k = count; k >= 0; k--)); do
  applied=("${patches[@]:0:k}")
  pending=("${patches[@]:k}")
  reversed=()
  for ((i = k - 1; i >= 0; i--)); do
    reversed+=("${applied[i]}")
  done
  cp "$snapshot" "$tmp/reverse"
  if ((k > 0)) && ! GIT_INDEX_FILE="$tmp/reverse" git -C Luma-Framework apply --cached --reverse "${reversed[@]}" 2>/dev/null; then
    continue
  fi
  cp "$snapshot" "$tmp/forward"
  if ((k < count)) && ! GIT_INDEX_FILE="$tmp/forward" git -C Luma-Framework apply --cached "${pending[@]}" 2>/dev/null; then
    continue
  fi
  for patch in "${applied[@]}"; do
    echo "already applied: patches/${patch##*/}"
  done
  if ((k < count)); then
    git -C Luma-Framework apply "${pending[@]}"
    for patch in "${pending[@]}"; do
      echo "applied: patches/${patch##*/}"
    done
  fi
  exit 0
done

echo "Luma-Framework's working tree doesn't match upstream with some of patches/ applied. Reset it with" >&2
echo "  git -C Luma-Framework checkout -- . && git -C Luma-Framework clean -fd" >&2
exit 1

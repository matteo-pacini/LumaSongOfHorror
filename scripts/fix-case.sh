#!/usr/bin/env bash
# Windows sources include headers with a different letter case than the files on disk.
# Builds the project repeatedly; for every "'<path>' file not found" error, finds the file
# case-insensitively in the search roots and adds symlinks with the spelling the source asked for.
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="${1:-build}"
roots=(.winsdk/sdk/include/ .xwin/crt/include Luma-Framework/Source Luma-Framework/Shaders)

link_case() { # $1 = wanted include path, $2 = file found on disk
  local -a want hit
  IFS=/ read -ra want <<<"$1"
  IFS=/ read -ra hit <<<"$2"
  local k nw=${#want[@]} nh=${#hit[@]} changed=1
  for ((k = 1; k <= nw; k++)); do
    local w=${want[nw - k]} h=${hit[nh - k]}
    [[ "$w" == ".." || "$w" == "." ]] && break
    local parent
    parent=$(IFS=/; echo "${hit[*]:0:nh-k}")
    if [[ "$w" != "$h" && ! -e "$parent/$w" ]]; then
      ln -s "$h" "$parent/$w"
      echo "linked $parent/$w -> $h"
      changed=0
    fi
  done
  return $changed
}

for _ in $(seq 1 100); do
  out=$(cmake --build "$build_dir" 2>&1 || true)
  missing=$(grep -oE "fatal error: '[^']+' file not found" <<<"$out" | sed -E "s/^fatal error: '(.*)' file not found$/\1/" | sort -u || true)
  # Import libraries named by "#pragma comment(lib, ...)" with a different case than the SDK's.
  missing_libs=$(grep -oE "lld-link: error: could not open '[^'/]+\.[lL][iI][bB]'" <<<"$out" | sed -E "s/.*could not open '(.*)'$/\1/" | sort -u || true)
  if [ -n "$missing_libs" ]; then
    lib_fixed=0
    while IFS= read -r want; do
      hit=$(find -L .winsdk/sdk/lib .xwin/crt/lib -iname "$want" 2>/dev/null | head -1)
      if [ -n "$hit" ] && [ ! -e "$(dirname "$hit")/$want" ]; then
        ln -s "$(basename "$hit")" "$(dirname "$hit")/$want"
        echo "linked $(dirname "$hit")/$want -> $(basename "$hit")"
        lib_fixed=1
      fi
    done <<<"$missing_libs"
    [ $lib_fixed = 1 ] && continue
    echo "unresolved libraries:"
    echo "$missing_libs"
    exit 1
  fi
  if [ -z "$missing" ]; then
    grep -E "error|FAILED" <<<"$out" | head -30 || echo "build OK"
    exit 0
  fi
  fixed=0
  while IFS= read -r want; do
    want=${want//\\//}
    lower_want=$(tr '[:upper:]' '[:lower:]' <<<"${want#./}")
    lower_want=${lower_want##*../}
    while IFS= read -r hit; do
      lower_hit=$(tr '[:upper:]' '[:lower:]' <<<"$hit")
      if [[ "$lower_hit" == *"/$lower_want" ]]; then
        link_case "$want" "$hit" && fixed=1
        break
      fi
    done < <(find -L "${roots[@]}" -iname "$(basename "$want")" 2>/dev/null)
  done <<<"$missing"
  if [ $fixed = 0 ]; then
    echo "unresolved includes:"
    echo "$missing"
    exit 1
  fi
done

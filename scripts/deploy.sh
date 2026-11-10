#!/usr/bin/env bash
# Installs the locally built addon and the Unreal Engine shaders into Song of Horror.
# The first run keeps the previously installed (release) files as *.orig; `--restore` puts them back.
set -euo pipefail
cd "$(dirname "$0")/.."

game_bin="${GAME_BIN:-/mnt/games/SteamLibrary/steamapps/common/SongOfHorror/SongOfHorror/Binaries/Win64}"
addon="$game_bin/Luma-Unreal Engine.addon"
shaders="$game_bin/Luma/Unreal Engine"
# Kept next to the addon rather than inside "Luma/", which then only holds the shader folders Luma ships.
shaders_backup="$game_bin/Luma-Unreal Engine.shaders.orig"

if pgrep -f '^S:.*SongOfHorror-Win64-Shipping\.exe' >/dev/null; then
  echo "Song of Horror is running; close it first." >&2
  exit 1
fi

if [ "${1:-}" = "--restore" ]; then
  [ -f "$addon.orig" ] && mv -f "$addon.orig" "$addon"
  [ -d "$shaders_backup" ] && rm -rf "$shaders" && mv "$shaders_backup" "$shaders"
  echo "Restored the original addon and shaders."
  exit 0
fi

build_dir="${1:-build}"
[ -f "$addon.orig" ] || cp "$addon" "$addon.orig"
[ -d "$shaders_backup" ] || cp -r "$shaders" "$shaders_backup"

cp "$build_dir/Luma-Unreal Engine.addon" "$addon"
cp -r "Luma-Framework/Shaders/Unreal Engine/." "$shaders/"
rm -rf "$shaders/Unused"
echo "Deployed $build_dir/Luma-Unreal Engine.addon and the Unreal Engine shaders to $game_bin"

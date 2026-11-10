#!/usr/bin/env bash
# Builds the release zip from a CMake build directory, with the same layout as Luma's own
# "Luma-Unreal_Engine.zip" (minus DLSS, see README), plus the third-party licenses.
# Usage: scripts/package.sh <build dir> <version>   ->   dist/LumaSongOfHorror-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

build_dir=$1
version=$2
luma=Luma-Framework
ext=$luma/Source/External

# ReShade with add-on support is the one binary not built here (it needs MSBuild). Take the build
# shipped in the Luma release that matches the pinned Luma-Framework commit.
reshade_zip_url=https://github.com/Filoppi/Luma-Framework/releases/download/latest-820/Luma-Unreal_Engine.zip
reshade_zip_sha256=2e5af486176134f605d53456a9650c1060ea98b1f75ba71ff6359f360cfb535e

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/pkg/Luma" "$stage/pkg/Licenses" dist

curl -sfL -o "$stage/luma.zip" "$reshade_zip_url"
echo "$reshade_zip_sha256  $stage/luma.zip" | sha256sum -c --quiet
bsdtar -xf "$stage/luma.zip" -C "$stage/pkg" dxgi.dll

cp "$build_dir/Luma-Unreal Engine.addon" "$stage/pkg/"
cp "$ext"/FidelityFX/bin/*.dll "$ext"/XeSS/bin/libxess.dll "$ext"/XeSS/bin/libxess_dx11.dll "$stage/pkg/"
cp "$luma/Shaders/Decompiler/d3dcompiler_47.dll" "$stage/pkg/Luma/"

# Shader folders, filtered like Luma's Scripts/package.ps1: no Unused/Dev/Sample/Dump folders,
# no Global/Textures (only used by mods with fast noise textures), only shader sources.
for mount in Global Includes "Unreal Engine"; do
  (cd "$luma/Shaders/$mount" && find . \
      \( -type d \( -name Unused -o -name Dev -o -name Sample -o -name 'Dump*' -o -path ./Textures \) -prune \) -o \
      \( -type f \( -name '*.hlsl' -o -name '*.hlsli' -o -name '*.h' -o -iname '*.recipe.yml' \) -print0 \)) |
    while IFS= read -r -d '' f; do
      mkdir -p "$stage/pkg/Luma/$mount/$(dirname "$f")"
      cp "$luma/Shaders/$mount/$f" "$stage/pkg/Luma/$mount/$f"
    done
done

cp LICENSE "$stage/pkg/Licenses/LumaSongOfHorror_LICENSE.txt"
cp "$luma/LICENSE.md" "$stage/pkg/Licenses/Luma_LICENSE.md"
cp "$ext/reshade/LICENSE.md" "$stage/pkg/Licenses/ReShade_LICENSE.md"
cp "$ext/FidelityFX/bin/FidelityFX_LICENSE.md" "$stage/pkg/Licenses/"
cp "$ext/XeSS/LICENSE.txt" "$stage/pkg/Licenses/XeSS_LICENSE.txt"
cp "$ext/XeSS/third-party-programs.txt" "$stage/pkg/Licenses/XeSS_third-party-programs.txt"
cp "$ext/safetyhook/LICENSE" "$stage/pkg/Licenses/SafetyHook_LICENSE.txt"
cp "$ext/zydis/LICENSE" "$stage/pkg/Licenses/Zydis_LICENSE.txt"
cp "$ext/zydis/dependencies/zycore/LICENSE" "$stage/pkg/Licenses/Zycore_LICENSE.txt"
cp "$ext/reshade/deps/stb/LICENSE" "$stage/pkg/Licenses/stb_LICENSE.txt"
cp third_party_licenses/NVIDIA_NVAPI_LICENSE.txt "$stage/pkg/Licenses/"

zip_name="LumaSongOfHorror-$version.zip"
rm -f "dist/$zip_name"
(cd "$stage/pkg" && bsdtar -a -cf "$OLDPWD/dist/$zip_name" -- *)
(cd dist && sha256sum "$zip_name" > "$zip_name.sha256")
echo "dist/$zip_name"

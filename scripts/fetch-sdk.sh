#!/usr/bin/env bash
# Fetches the Windows build dependencies into the project root (run inside `nix develop`).
# Both downloads are covered by Microsoft's Visual Studio / Windows SDK license terms, which
# running this script accepts.
#   .xwin/crt    MSVC CRT + STL headers and import libs, via xwin
#   .winsdk/sdk  Windows SDK 10.0.26100 (Luma requires it; xwin 0.9.0 cannot find its x64 headers),
#                from the official Microsoft.Windows.SDK.CPP NuGet packages
set -euo pipefail
cd "$(dirname "$0")/.."

sdk_version=10.0.26100.9457
declare -A sdk_sha256=(
  [microsoft.windows.sdk.cpp]=1c8b332abba402808880ddba4d70e663f834ded44cf4771a2c191e9485e7cdcd
  [microsoft.windows.sdk.cpp.x64]=52bd17c63d3b6d268f385c358f34d0eb595b9c1deb3273855abd2ec5c095d132
)

if [ ! -d .xwin/crt ]; then
  xwin --accept-license --arch x86_64 --sdk-version 10.0.22621 --cache-dir .xwin-cache splat --output .xwin
fi

if [ ! -d .winsdk/sdk ]; then
  mkdir -p .winsdk/dl
  for pkg in "${!sdk_sha256[@]}"; do
    if [ ! -d ".winsdk/$pkg" ]; then
      curl -sfL -o ".winsdk/dl/$pkg.nupkg" "https://api.nuget.org/v3-flatcontainer/$pkg/$sdk_version/$pkg.$sdk_version.nupkg"
      echo "${sdk_sha256[$pkg]}  .winsdk/dl/$pkg.nupkg" | sha256sum -c --quiet
      mkdir ".winsdk/$pkg"
      bsdtar -xf ".winsdk/dl/$pkg.nupkg" -C ".winsdk/$pkg"
    fi
  done

  inc=".winsdk/microsoft.windows.sdk.cpp/c/Include/${sdk_version%.*}.0"
  mkdir -p .winsdk/sdk/include .winsdk/sdk/lib/um .winsdk/sdk/lib/ucrt
  for d in um shared ucrt winrt cppwinrt; do
    ln -sfn "../../${inc#.winsdk/}/$d" ".winsdk/sdk/include/$d"
  done
  ln -sfn ../../../microsoft.windows.sdk.cpp.x64/c/um/x64 .winsdk/sdk/lib/um/x86_64
  ln -sfn ../../../microsoft.windows.sdk.cpp.x64/c/ucrt/x64 .winsdk/sdk/lib/ucrt/x86_64

  # The SDK's file names are mixed case while sources and #pragma comment(lib) mostly use lower
  # case; add an all-lowercase alias next to every header and import library.
  find -L .winsdk/sdk/include .winsdk/sdk/lib -type f | while IFS= read -r f; do
    dir=$(dirname "$f")
    name=$(basename "$f")
    lower=$(tr '[:upper:]' '[:lower:]' <<<"$name")
    if [ "$name" != "$lower" ] && [ ! -e "$dir/$lower" ]; then
      ln -s "$name" "$dir/$lower"
    fi
  done

  # Spellings used by the SDK's own headers and by Luma that match neither the file name nor its
  # lowercase alias (found with scripts/fix-case.sh).
  ln -sf driverspecs.h .winsdk/sdk/include/shared/DriverSpecs.h
  ln -sf specstrings.h .winsdk/sdk/include/shared/SpecStrings.h
  ln -sf highlevelmonitorconfigurationapi.h .winsdk/sdk/include/um/HighLevelMonitorConfigurationAPI.h
  ln -sf physicalmonitorenumerationapi.h .winsdk/sdk/include/um/PhysicalMonitorEnumerationAPI.h
  ln -sf dxva2.lib .winsdk/sdk/lib/um/x86_64/Dxva2.lib
  ln -sf version.lib .winsdk/sdk/lib/um/x86_64/Version.lib
fi
echo "SDK ready: .xwin/crt and .winsdk/sdk"

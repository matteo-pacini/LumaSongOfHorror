# LumaSongOfHorror

A patched build of the generic Unreal Engine mod from [Luma Framework](https://github.com/Filoppi/Luma-Framework)
that lets FSR 4 (and FSR 3 / XeSS) **upscale** in *Song of Horror*, instead of only anti-aliasing at
native resolution.

Luma Framework is made by Filippo "Pumbo" Tarpini and its contributors. This project is not
affiliated with them; it only carries two small patches on top of their code. All credit for the
mod itself goes to the Luma authors.

> Developed and tested on **Linux only**: AMD Radeon RX 6800 XT (RDNA 2), FSR 4 (INT8), a
> Proton-CachyOS 11.0 based build. Windows, NVIDIA GPUs and other Unreal Engine games are untested.

## What the patches change

Luma's Unreal Engine mod replaces the game's TAA with an upscaler, but always told the upscaler that
the game rendered at full output resolution, so it could only be used as native AA. With Unreal's
screen percentage below 100% and TAA upsampling enabled, the patched mod:

- passes the resolution the game actually rendered at (from the game's per-view constants) to the
  upscaler, so FSR upscales from it to the output resolution;
- accepts the slightly different aspect ratio of the rounded-down render resolution;
- decodes motion vectors with texture coordinates based on the real size of Unreal's scene
  textures, which are padded beyond the render resolution.

A second patch only makes Luma build with clang-cl. The patches are in [`patches/`](patches); the
Luma source is the [`Luma-Framework`](Luma-Framework) submodule, pinned to the upstream commit
they apply to.

DLSS is not included in this build: NVIDIA's DLSS SDK license requires NVIDIA branding inside the
application, which a mod cannot provide.

## Installation

1. Download `LumaSongOfHorror-<version>.zip` from the
   [releases](https://github.com/matteo-pacini/LumaSongOfHorror/releases) and extract it into the
   folder with the game's executable:
   `steamapps/common/SongOfHorror/SongOfHorror/Binaries/Win64/`
   (next to `SongOfHorror-Win64-Shipping.exe`).
2. In Steam, set the game's compatibility tool to Proton-CachyOS.
3. Install the Visual C++ 2022 runtime in the game's prefix (the one Steam installs is too old for
   the mod):
   ```sh
   protontricks 1096570 -q vcrun2022
   ```
4. Launch the game once and quit, so it creates its config files. Then add the lines below to
   `steamapps/compatdata/1096570/pfx/drive_c/users/steamuser/AppData/Local/SongOfHorror/Saved/Config/WindowsNoEditor/Engine.ini`
   (in the Steam library that contains the game). Edit it only while the game is closed, as the
   game rewrites the file when it exits.
   ```ini
   [SystemSettings]
   r.DefaultFeature.AntiAliasing=2
   r.PostProcessAAQuality=4
   r.TemporalAA.Upsampling=1

   [/Script/Engine.Engine]
   bSmoothFrameRate=False
   ```
5. Set the game's launch options:
   ```sh
   FSR4_UPGRADE=1 PROTON_FSR4_UPGRADE=1 WINEDLLOVERRIDES="dxgi=n,b" %command% -dx11
   ```
   Optional extras that were used during testing: `PROTON_ENABLE_WAYLAND=1`, `MANGOHUD=1` and
   `gamemoderun` (before `%command%`).
6. In game, set the resolution scale in the video options to the render resolution you want
   (67% was tested at 2560x1440). Press `Home` to open the ReShade/Luma overlay and set
   **Super Resolution** to **FSR 4 (DX12 Interop)**.

### What the settings do

| Setting | Purpose |
|---|---|
| `r.DefaultFeature.AntiAliasing=2`, `r.PostProcessAAQuality=4` | Forces Unreal's TAA on; Luma replaces that pass with the upscaler. |
| `r.TemporalAA.Upsampling=1` | Makes TAA output at full resolution from the lower render resolution. Without it the game upscales the image itself after TAA, and FSR only anti-aliases. |
| `bSmoothFrameRate=False` | Removes the default 62 FPS cap. |
| `PROTON_FSR4_UPGRADE=1` | Proton-CachyOS downloads AMD's FSR 4 driver component (`amdxcffx64.dll`) into the prefix. |
| `FSR4_UPGRADE=1` | Read by Proton-CachyOS's AMD driver layer (`amdxc64`) to offer FSR 4 on GPUs older than RDNA 4. |
| `WINEDLLOVERRIDES="dxgi=n,b"` | Loads ReShade (the mod's `dxgi.dll`) instead of Wine's built-in DXGI. |
| `-dx11` | The mod only supports DirectX 11. |

## Troubleshooting

- **"Fatal error" right at startup:** the Visual C++ 2022 runtime is missing from the prefix
  (installation step 3).
- **The game crashes or hangs with no window:** the Mesa anti-lag Vulkan layer
  (`ENABLE_LAYER_MESA_ANTI_LAG=1`) and Proton's OptiScaler (`PROTON_USE_OPTISCALER=1`) both crash
  or hang the game with this mod. Leave them out of the launch options.
- **No upscaling:** check that `r.TemporalAA.Upsampling=1` is still in `Engine.ini`, and that the
  in-game resolution scale is below 100%. Luma's log (`ReShade.log` next to the executable) shows
  `FSR4: Created context (render <render size>, output <output size>)`.
- **FPS stuck at 62:** check `bSmoothFrameRate=False` in `Engine.ini`.

## Building

The addon is cross-compiled on Linux with clang-cl and lld-link against the MSVC runtime (via
[xwin](https://github.com/Jake-Shadle/xwin)) and the Windows SDK (from Microsoft's
`Microsoft.Windows.SDK.CPP` NuGet packages). Everything else comes from the Nix devShell.

```sh
git clone --recursive https://github.com/matteo-pacini/LumaSongOfHorror
cd LumaSongOfHorror
nix develop

./scripts/apply-patches.sh   # applies patches/ to the Luma-Framework working tree
./scripts/fetch-sdk.sh       # downloads the MSVC runtime and Windows SDK; accepts Microsoft's license terms
cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/clang-cl-xwin.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Development helpers:

- `./scripts/deploy.sh build` copies the built addon and the Unreal Engine shaders into the game
  (set `GAME_BIN` if the game is not in `/mnt/games/SteamLibrary`); `./scripts/deploy.sh --restore`
  puts the previous files back.
- `-DLUMA_TEST_BUILD=ON` builds like Luma's Test configuration, which adds an **Info** tab to the
  overlay with the render and output resolution.
- `./scripts/package.sh build <version>` creates the release zip in `dist/`.
- `./scripts/fix-case.sh` rebuilds until no include or library is missing, adding symlinks for
  file names that only differ in letter case (Windows sources are not case sensitive). It is only
  needed after updating Luma-Framework.

`compat/atlbase.h` stands in for the few ATL classes Luma uses, as xwin does not ship ATL.

CI ([`.github/workflows/build.yml`](.github/workflows/build.yml)) builds and packages every push;
pushing a `v*` tag publishes the zip as a GitHub release.

## License

The files of this repository are MIT licensed ([LICENSE](LICENSE)). The patches, Luma Framework
and the built addon are covered by Luma Framework's license ([LICENSE.Luma](LICENSE.Luma)), which
requires crediting its authors and asking them before any commercial use. The release zip also
contains ReShade, AMD FidelityFX, Intel XeSS and other third-party components; their licenses are
in its `Licenses/` folder.

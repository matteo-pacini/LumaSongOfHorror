# AGENTS.md

Notes for coding agents working on this repository. User-facing documentation is in
[README.md](README.md).

## What this is

A patched build of Luma Framework's generic Unreal Engine mod (a ReShade add-on) that makes FSR 4,
FSR 3 and XeSS upscale in *Song of Horror* (Steam app 1096570, Unreal Engine 4.21.2, DirectX 11).
Upstream only ran them as native-resolution anti-aliasing. Developed and tested only on Linux:
Proton-CachyOS, RX 6800 XT, FSR 4 INT8, Steam build 8260563.

## Layout

- `Luma-Framework/`: upstream submodule, pinned to commit `8f91e14`. Never commit to it: our changes
  live in `patches/` and are applied to its working tree by `scripts/apply-patches.sh`.
- `patches/0001`: clang-cl build fixes (rvalue `com_ptr` casts only MSVC accepts).
- `patches/0002`: pass UE's real render resolution to the upscaler, decode motion vectors with UVs
  relative to the scene textures' real size, relax the TAA output aspect check.
- `patches/0003`: the "Render Resolution" setting (overrides `r.ScreenPercentage` and
  `r.TemporalAA.Upsampling`), fixes for SR below ~71%, and Test-build diagnostics.
- `flake.nix`, `cmake/`, `CMakeLists.txt`: Linux cross build (clang-cl, lld-link) replacing
  upstream's MSBuild project. DLSS/NGX is deliberately not built (NVIDIA's license requires
  branding a mod can't provide).
- `compat/atlbase.h`: stand-in for the ATL classes Luma uses (xwin has no ATL).
- `scripts/`: `fetch-sdk.sh` (MSVC CRT via xwin, Windows SDK 10.0.26100 via NuGet), `apply-patches.sh`,
  `deploy.sh` (install into the game, `--restore`), `package.sh` (release zips), `fix-case.sh`.
- `.github/workflows/build.yml`: builds the release and Test zips on every push; `v*` tags publish them.

## Workflow

```sh
nix develop
./scripts/apply-patches.sh
./scripts/fetch-sdk.sh
cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/clang-cl-xwin.cmake -DCMAKE_BUILD_TYPE=Release   # add -DLUMA_TEST_BUILD=ON for the Test variant
cmake --build build
./scripts/deploy.sh build   # the game must be closed
```

To change the patches: in `Luma-Framework`, create a branch at `8f91e14`, `git am ../patches/*.patch`,
commit the change, then `git format-patch -N -o ../patches` (where N is the number of patches).
Finally detach back to `8f91e14` and run `scripts/apply-patches.sh`, so the submodule pointer stays
on upstream.

Test in game by reading `ReShade.log` next to the executable: `FSR4: Created context (render WxH,
output WxH)` is logged whenever the upscaler is (re)created, so every render resolution change shows
up. Test builds also log why a TAA pass skipped the upscaler. The game must be closed before
deploying or editing `Engine.ini` (the game rewrites it on exit, with CRLF line endings).

## History

1. Luma's Unreal Engine mod (release latest-820) loaded in the game but crashed at startup in
   `MSVCP140.dll`. The prefix had the VS2015 runtime, and Luma is built with MSVC v145. Fixed by
   `protontricks 1096570 -q vcrun2022`.
2. The game then exited right after FSR 4 started. `PROTON_LOG=1` showed a null read in Mesa's
   anti-lag Vulkan layer on the D3D12 interop queue, so `ENABLE_LAYER_MESA_ANTI_LAG` was dropped.
   Proton's OptiScaler hangs the game while FSR 4 initializes, so it isn't used.
3. `Engine.ini` forces TAA (`r.DefaultFeature.AntiAliasing=2`, `r.PostProcessAAQuality=4`) and
   removes the 62 FPS smoothing cap (`bSmoothFrameRate=False`).
4. The mod always used the swapchain size as render resolution (DLAA only). Patch 0002 takes it from
   UE's per-view constants. It works with `r.ScreenPercentage` < 100 and `r.TemporalAA.Upsampling=1`.
5. The game's own resolution option stores the screen percentage itself (`Video_CalidadRenderizado`
   in `SaveGames/SlotGlobal.sav`), with a minimum of 70%, so it can't reach FSR's presets.
   `-ExecCmds` and `Engine.ini` values are overridden by the game.
6. Patch 0003 writes the console variables directly. The exe's code is encrypted on disk (Steam DRM)
   and only readable in memory, so it was analysed from an in-process dump made by a temporary,
   uncommitted build. `includes/console_variables.hpp` finds each variable's data pointer at runtime
   from the code pattern UE generates around its name, and the value is rewritten every frame.
7. Below ~71%, SR still didn't run. UE rounds the view size (1708x960 at 66.7% of 2560x1440) beyond
   the old aspect tolerance, and its TAA jitter exceeds half a pixel. Both checks were relaxed. UE
   also switches to another TAA shader (`0xC828F120`) below ~71%.
8. The README comparison was captured from inside the game by a temporary build that called ReShade's
   `save_screenshot()` when a trigger file appeared. That code was not committed either.

## Known issues

- If the game starts at a render resolution above ~71% and the preset is then lowered below it, Luma
  never inspects the lower resolution TAA shader UE creates mid-session, so it isn't replaced until
  the game restarts. The cause in Luma's shader patching path (`Core/includes/patch.inl`,
  `PatchShaderSync`) hasn't been found yet.
- Each preset change recreates the FSR context three times (UE applies the new view size a frame late).
- Only Steam build 8260563 is supported; the console variable lookup depends on its code.
- Only FSR 4 (Luma's DX12 interop path, upgraded to INT8 by Proton-CachyOS) was tested. FSR 3 (native
  DX11) and XeSS (DX12 interop on non-Intel GPUs) are compiled in but were never selected in game.

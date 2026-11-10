{
  description = "Build the Luma Unreal Engine addon (Song of Horror upscaling patch) on Linux with clang-cl + lld-link";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      llvm = pkgs.llvmPackages_20;
    in
    {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          llvm.clang-unwrapped # clang-cl
          llvm.lld # lld-link
          llvm.llvm # llvm-lib, llvm-rc, llvm-mt
          pkgs.cmake
          pkgs.ninja
          pkgs.xwin
          pkgs.curl
          pkgs.libarchive # bsdtar, to unpack the SDK NuGet packages
        ];

        # clang-unwrapped keeps its builtin headers (intrin.h, immintrin.h, ...) in the "lib" output,
        # which the unwrapped driver does not find on its own.
        CLANG_RESOURCE_DIR = "${llvm.clang-unwrapped.lib}/lib/clang/20";

        shellHook = ''
          export MSVC_CRT_DIR="$PWD/.xwin/crt"
          export WINSDK_DIR="$PWD/.winsdk/sdk"
          if [ ! -d "$MSVC_CRT_DIR" ] || [ ! -d "$WINSDK_DIR" ]; then
            echo "MSVC CRT / Windows SDK missing. Fetch them once (accepts Microsoft's license terms):"
            echo "  ./scripts/fetch-sdk.sh"
          fi
          echo "Configure: cmake -S . -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/clang-cl-xwin.cmake"
          echo "Build:     cmake --build build"
          echo "Deploy:    ./scripts/deploy.sh build"
        '';
      };
    };
}

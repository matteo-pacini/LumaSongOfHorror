# Cross-compile Windows x64 binaries from Linux with clang-cl and lld-link.
#   $MSVC_CRT_DIR  MSVC CRT/STL headers and import libs (xwin layout: include/, lib/x86_64/)
#   $WINSDK_DIR    Windows SDK headers and import libs (xwin layout: include/{ucrt,um,shared,winrt}, lib/{um,ucrt}/x86_64/)
# Both are prepared by scripts/fetch-sdk.sh and exported by the devShell.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(CMAKE_C_COMPILER clang-cl)
set(CMAKE_CXX_COMPILER clang-cl)
set(CMAKE_LINKER lld-link)
set(CMAKE_AR llvm-lib)
set(CMAKE_RC_COMPILER llvm-rc)
set(CMAKE_MT llvm-mt)

foreach(_var MSVC_CRT_DIR WINSDK_DIR)
  if(NOT DEFINED ENV{${_var}})
    message(FATAL_ERROR "${_var} is not set (enter the devShell with `nix develop`)")
  endif()
endforeach()
set(MSVC_CRT_DIR "$ENV{MSVC_CRT_DIR}")
set(WINSDK_DIR "$ENV{WINSDK_DIR}")

set(_compile_flags
  "--target=x86_64-pc-windows-msvc"
  # The CRT's STL rejects compilers that report an older MSVC version than the one it ships with.
  "-fms-compatibility-version=19.44"
  "/imsvc${MSVC_CRT_DIR}/include"
  "/imsvc${WINSDK_DIR}/include/ucrt"
  "/imsvc${WINSDK_DIR}/include/um"
  "/imsvc${WINSDK_DIR}/include/shared"
  "/imsvc${WINSDK_DIR}/include/winrt"
)
if(DEFINED ENV{CLANG_RESOURCE_DIR})
  list(APPEND _compile_flags "/clang:-resource-dir=$ENV{CLANG_RESOURCE_DIR}")
endif()
list(JOIN _compile_flags " " _compile_flags)

set(CMAKE_C_FLAGS_INIT "${_compile_flags}")
set(CMAKE_CXX_FLAGS_INIT "${_compile_flags}")

set(_link_flags
  "/libpath:${MSVC_CRT_DIR}/lib/x86_64"
  "/libpath:${WINSDK_DIR}/lib/um/x86_64"
  "/libpath:${WINSDK_DIR}/lib/ucrt/x86_64"
)
list(JOIN _link_flags " " _link_flags)
set(CMAKE_EXE_LINKER_FLAGS_INIT "${_link_flags}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_link_flags}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_link_flags}")

# xwin only ships the release CRT import libs (no msvcrtd.lib), so compiler checks must not use the debug runtime.
set(CMAKE_TRY_COMPILE_CONFIGURATION Release)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

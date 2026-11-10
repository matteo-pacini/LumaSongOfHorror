# Builds "Luma-Unreal Engine.addon" from ./Luma-Framework with the feature set of its
# "Unreal Engine.vcxproj" (FSR 3/4, XeSS, D3D12 interop, SafetyHook, NVAPI), without MSBuild.
# DLSS (NGX) is left out: NVIDIA's SDK license requires NVIDIA branding in the application.
cmake_minimum_required(VERSION 3.25)
project(LumaUnrealEngine LANGUAGES C CXX)

set(LUMA_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/Luma-Framework" CACHE PATH "Luma-Framework checkout")
option(LUMA_TEST_BUILD "Build like the Test-Release configuration (TEST=1: adds the Info tab and extra logging)" OFF)

set(SRC "${LUMA_ROOT}/Source")
set(EXT "${SRC}/External")
set(GAME_DIR "${SRC}/Games/Unreal Engine")

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)

file(GLOB ZYDIS_SOURCES "${EXT}/zydis/src/*.c")
file(GLOB ZYCORE_SOURCES "${EXT}/zydis/dependencies/zycore/src/*.c" "${EXT}/zydis/dependencies/zycore/src/API/*.c")
set(SAFETYHOOK_SOURCES
  "${EXT}/safetyhook/src/allocator.cpp"
  "${EXT}/safetyhook/src/easy.cpp"
  "${EXT}/safetyhook/src/inline_hook.cpp"
  "${EXT}/safetyhook/src/mid_hook.cpp"
  "${EXT}/safetyhook/src/os.windows.cpp"
  "${EXT}/safetyhook/src/utility.cpp"
  "${EXT}/safetyhook/src/vmt_hook.cpp"
)
set(LUMA_SOURCES
  "${SRC}/Core/unity_build.cpp"
  "${GAME_DIR}/main.cpp"
)

add_library(luma_unreal_engine SHARED ${LUMA_SOURCES} ${SAFETYHOOK_SOURCES} ${ZYDIS_SOURCES} ${ZYCORE_SOURCES})
set_target_properties(luma_unreal_engine PROPERTIES
  OUTPUT_NAME "Luma-Unreal Engine"
  PREFIX ""
  SUFFIX ".addon"
)

target_include_directories(luma_unreal_engine PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/compat" # atlbase.h stand-in
  "${EXT}/reshade"
  "${EXT}/WDK/includes"
  "${EXT}/FidelityFX"
  "${EXT}/XeSS/inc"
  "${EXT}/NVAPI"
  "${EXT}/safetyhook/include"
  "${EXT}/zydis/include"
  "${EXT}/zydis/dependencies/zycore/include"
  "${EXT}/zydis/src"
)

target_compile_definitions(luma_unreal_engine PRIVATE
  UNICODE _UNICODE _WINDOWS NDEBUG
  "PROJECT_NAME=\"Unreal Engine\""
  ENABLE_FIDELITY_SK=1
  ENABLE_FSR4=1
  ENABLE_XESS=1
  ENABLE_D3D12_INTEROP=1
  ENABLE_SAFETYHOOK=1 ZYDIS_STATIC_BUILD ZYCORE_STATIC_BUILD
  ENABLE_NVAPI=1
  $<$<BOOL:${LUMA_TEST_BUILD}>:TEST=1>
)

target_compile_options(luma_unreal_engine PRIVATE
  /O2 /bigobj /utf-8
  # Third-party and Luma sources are written for MSVC; keep the build log readable.
  /clang:-w
  $<$<COMPILE_LANGUAGE:CXX>:/std:c++latest /EHsc /GR /Zc:strictStrings /Zc:threadSafeInit>
  $<$<COMPILE_LANGUAGE:C>:/std:c17>
)

# Same as the vcxproj's ForcedIncludeFiles, which only applies to the Luma sources.
set_source_files_properties(${LUMA_SOURCES} PROPERTIES
  COMPILE_OPTIONS "/FI${LUMA_ROOT}/Shaders/Unreal Engine/includes/GameCBuffers.hlsl"
)

target_link_directories(luma_unreal_engine PRIVATE
  "${EXT}/FidelityFX/libs"
  "${EXT}/NVAPI/amd64"
)
target_link_libraries(luma_unreal_engine PRIVATE
  ffx_backend_dx11_x64 ffx_fsr3_x64 ffx_frameinterpolation_x64 ffx_fsr3upscaler_x64 ffx_opticalflow_x64
  nvapi64
)

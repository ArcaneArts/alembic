# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(alembic LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "Alembic")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
#
# Flutter normally builds Windows plugins through generated directory symlinks
# under flutter/ephemeral/.plugin_symlinks. Some locked-down Windows setups can
# create those links but cannot traverse them during CMake/Dart package
# resolution. Staging each plugin from its real package root into the build tree
# avoids untrusted mount-point traversal and avoids plugin tooling warnings from
# resolving hidden AppData path segments.
function(STAGE_FLUTTER_PLUGIN_SOURCE PLUGIN_NAME PLUGIN_PACKAGE_DIR OUT_VAR)
  set(STAGED_PLUGIN_DIR "${CMAKE_CURRENT_BINARY_DIR}/flutter_plugin_sources/${PLUGIN_NAME}")
  set(STAGED_PLUGIN_MARKER "${STAGED_PLUGIN_DIR}/.alembic_source_path")
  set(SHOULD_COPY TRUE)

  if(EXISTS "${STAGED_PLUGIN_DIR}/windows/CMakeLists.txt" AND EXISTS "${STAGED_PLUGIN_MARKER}")
    file(READ "${STAGED_PLUGIN_MARKER}" STAGED_SOURCE_PATH)
    if("${STAGED_SOURCE_PATH}" STREQUAL "${PLUGIN_PACKAGE_DIR}")
      set(SHOULD_COPY FALSE)
    endif()
  endif()

  if(SHOULD_COPY)
    file(REMOVE_RECURSE "${STAGED_PLUGIN_DIR}")
    file(MAKE_DIRECTORY "${STAGED_PLUGIN_DIR}")
    file(COPY "${PLUGIN_PACKAGE_DIR}/" DESTINATION "${STAGED_PLUGIN_DIR}")
    file(WRITE "${STAGED_PLUGIN_MARKER}" "${PLUGIN_PACKAGE_DIR}")
  endif()

  file(GLOB_RECURSE STAGED_CARGOKIT_CMAKE_FILES "${STAGED_PLUGIN_DIR}/cargokit/cmake/cargokit.cmake")
  foreach(STAGED_CARGOKIT_CMAKE_FILE ${STAGED_CARGOKIT_CMAKE_FILES})
    file(READ "${STAGED_CARGOKIT_CMAKE_FILE}" STAGED_CARGOKIT_CMAKE_CONTENT)
    string(REPLACE
      [[if(WIN32)
    # REALPATH does not properly resolve symlinks on windows :-/
    execute_process(COMMAND powershell -ExecutionPolicy Bypass -File "${CMAKE_CURRENT_LIST_DIR}/resolve_symlinks.ps1" "${cargokit_cmake_root}" OUTPUT_VARIABLE cargokit_cmake_root OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()]]
      [[if(WIN32)
    # Alembic stages Flutter plugin sources into the generated build tree before
    # including plugin CMake. The staged Cargokit path is already real, so avoid
    # invoking resolve_symlinks.ps1, which can emit noisy hidden AppData path
    # warnings on locked-down Windows configurations.
endif()]]
      STAGED_CARGOKIT_CMAKE_CONTENT
      "${STAGED_CARGOKIT_CMAKE_CONTENT}"
    )
    file(WRITE "${STAGED_CARGOKIT_CMAKE_FILE}" "${STAGED_CARGOKIT_CMAKE_CONTENT}")
  endforeach()

  set(${OUT_VAR} "${STAGED_PLUGIN_DIR}/windows" PARENT_SCOPE)
endfunction()

function(RESOLVE_FLUTTER_PLUGIN_WINDOWS_DIR PLUGIN_NAME OUT_VAR)
  set(PLUGIN_SYMLINK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/${PLUGIN_NAME}")
  set(PLUGIN_SYMLINK_WINDOWS_DIR "${PLUGIN_SYMLINK_DIR}/windows")

  if(IS_SYMLINK "${PLUGIN_SYMLINK_DIR}")
    file(READ_SYMLINK "${PLUGIN_SYMLINK_DIR}" PLUGIN_PACKAGE_DIR)
    if(NOT IS_ABSOLUTE "${PLUGIN_PACKAGE_DIR}")
      get_filename_component(PLUGIN_PACKAGE_DIR "${PLUGIN_SYMLINK_DIR}/../${PLUGIN_PACKAGE_DIR}" ABSOLUTE)
    endif()
    file(TO_CMAKE_PATH "${PLUGIN_PACKAGE_DIR}" PLUGIN_PACKAGE_DIR)
    if(EXISTS "${PLUGIN_PACKAGE_DIR}/windows/CMakeLists.txt")
      STAGE_FLUTTER_PLUGIN_SOURCE(${PLUGIN_NAME} "${PLUGIN_PACKAGE_DIR}" STAGED_PLUGIN_WINDOWS_DIR)
      set(${OUT_VAR} "${STAGED_PLUGIN_WINDOWS_DIR}" PARENT_SCOPE)
      return()
    endif()
  endif()

  set(PLUGIN_CACHE_ROOTS)
  if(DEFINED ENV{PUB_CACHE})
    file(TO_CMAKE_PATH "$ENV{PUB_CACHE}/hosted/pub.dev" PUB_CACHE_HOSTED_DIR)
    list(APPEND PLUGIN_CACHE_ROOTS "${PUB_CACHE_HOSTED_DIR}")
  endif()
  if(DEFINED ENV{LOCALAPPDATA})
    file(TO_CMAKE_PATH "$ENV{LOCALAPPDATA}/Pub/Cache/hosted/pub.dev" LOCAL_APP_DATA_PUB_CACHE_HOSTED_DIR)
    list(APPEND PLUGIN_CACHE_ROOTS "${LOCAL_APP_DATA_PUB_CACHE_HOSTED_DIR}")
  endif()

  foreach(PLUGIN_CACHE_ROOT ${PLUGIN_CACHE_ROOTS})
    file(GLOB PLUGIN_WINDOWS_DIRS LIST_DIRECTORIES true "${PLUGIN_CACHE_ROOT}/${PLUGIN_NAME}-*/windows")
    if(PLUGIN_WINDOWS_DIRS)
      list(SORT PLUGIN_WINDOWS_DIRS)
      list(GET PLUGIN_WINDOWS_DIRS 0 PLUGIN_WINDOWS_DIR)
      get_filename_component(PLUGIN_PACKAGE_DIR "${PLUGIN_WINDOWS_DIR}/.." ABSOLUTE)
      if(EXISTS "${PLUGIN_PACKAGE_DIR}/windows/CMakeLists.txt")
        message(STATUS "Staging Windows plugin source for ${PLUGIN_NAME}")
        STAGE_FLUTTER_PLUGIN_SOURCE(${PLUGIN_NAME} "${PLUGIN_PACKAGE_DIR}" STAGED_PLUGIN_WINDOWS_DIR)
        set(${OUT_VAR} "${STAGED_PLUGIN_WINDOWS_DIR}" PARENT_SCOPE)
        return()
      endif()
    endif()
  endforeach()

  if(EXISTS "${PLUGIN_SYMLINK_WINDOWS_DIR}/CMakeLists.txt")
    set(${OUT_VAR} "${PLUGIN_SYMLINK_WINDOWS_DIR}" PARENT_SCOPE)
    return()
  endif()

  message(FATAL_ERROR "Unable to resolve Windows plugin '${PLUGIN_NAME}'. Expected '${PLUGIN_SYMLINK_WINDOWS_DIR}' or a Pub cache entry under PUB_CACHE/LOCALAPPDATA.")
endfunction()

function(REPAIR_FLUTTER_PLUGIN_CMAKE_PATHS OUT_VAR)
  set(PLUGIN_CMAKE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake")
  set(REPAIRED_PLUGIN_CMAKE_FILE "${CMAKE_CURRENT_BINARY_DIR}/generated_plugins.repaired.cmake")
  if(NOT EXISTS "${PLUGIN_CMAKE_FILE}")
    message(FATAL_ERROR "Unable to find generated Flutter plugin CMake file: ${PLUGIN_CMAKE_FILE}")
  endif()

  file(READ "${PLUGIN_CMAKE_FILE}" PLUGIN_CMAKE_CONTENT)
  string(REPLACE
    [[add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})]]
    [[RESOLVE_FLUTTER_PLUGIN_WINDOWS_DIR(${plugin} PLUGIN_WINDOWS_DIR)
  add_subdirectory("${PLUGIN_WINDOWS_DIR}" plugins/${plugin})]]
    PLUGIN_CMAKE_CONTENT
    "${PLUGIN_CMAKE_CONTENT}"
  )
  string(REPLACE
    [[add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})]]
    [[RESOLVE_FLUTTER_PLUGIN_WINDOWS_DIR(${ffi_plugin} FFI_PLUGIN_WINDOWS_DIR)
  add_subdirectory("${FFI_PLUGIN_WINDOWS_DIR}" plugins/${ffi_plugin})]]
    PLUGIN_CMAKE_CONTENT
    "${PLUGIN_CMAKE_CONTENT}"
  )
  file(WRITE "${REPAIRED_PLUGIN_CMAKE_FILE}" "${PLUGIN_CMAKE_CONTENT}")
  set(${OUT_VAR} "${REPAIRED_PLUGIN_CMAKE_FILE}" PARENT_SCOPE)
endfunction()

REPAIR_FLUTTER_PLUGIN_CMAKE_PATHS(REPAIRED_PLUGIN_CMAKE_FILE)
include("${REPAIRED_PLUGIN_CMAKE_FILE}")


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

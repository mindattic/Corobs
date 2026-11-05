cmake_minimum_required(VERSION 3.20)
project(corobs VERSION 0.1.0 DESCRIPTION "Correlithm Object technology: a pure, deterministic C++ port of Corobs" LANGUAGES CXX)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  set(_corobs_top_level ON)
else()
  set(_corobs_top_level OFF)
endif()
option(COROBS_BUILD_TESTS "Build the Corobs unit tests (fetches GoogleTest and nlohmann/json)" ${_corobs_top_level})

add_library(corobs
  src/seeding.cpp
  src/geometry.cpp
  src/strings.cpp
  src/converters.cpp)
add_library(corobs::corobs ALIAS corobs)

target_compile_features(corobs PUBLIC cxx_std_20)
target_include_directories(corobs PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)

# Bit-for-bit conformance: every multiply and add rounds on its own (conformance/README.md, trap 4).
if(MSVC)
  target_compile_options(corobs PRIVATE /fp:precise /W4 /WX /utf-8)
else()
  target_compile_options(corobs PRIVATE -ffp-contract=off -Wall -Wextra -Wpedantic -Werror)
endif()

# Purity: the library links nothing.
get_target_property(_corobs_links corobs LINK_LIBRARIES)
get_target_property(_corobs_interface_links corobs INTERFACE_LINK_LIBRARIES)
if(_corobs_links OR _corobs_interface_links)
  message(FATAL_ERROR "corobs must link nothing; found: ${_corobs_links} ${_corobs_interface_links}")
endif()

if(COROBS_BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()

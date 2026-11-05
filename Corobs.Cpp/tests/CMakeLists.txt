include(FetchContent)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)
set(JSON_BuildTests OFF CACHE INTERNAL "")

FetchContent_Declare(googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.tar.gz
  URL_HASH SHA256=7b42b4d6ed48810c5362c265a17faebe90dc2373c885e5216439d37927f02926)
FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
  URL_HASH SHA256=d6c65aca6b1ed68e7a182f4757257b107ae403032760ed6ef121c9d55e81757d)
FetchContent_MakeAvailable(googletest nlohmann_json)

add_executable(corobs_tests
  ncube_tests.cpp
  seeded_prng_tests.cpp
  string_co_tests.cpp
  converter_tests.cpp
  mining_tests.cpp
  bench_tests.cpp
  bugs_cor_t4_tests.cpp
  bugs_cor_t5_tests.cpp
  conformance_tests.cpp
  purity_tests.cpp)

file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/corobs_test_config.hpp CONTENT
"#pragma once
#define COROBS_VECTORS_PATH \"${CMAKE_CURRENT_SOURCE_DIR}/../../conformance/vectors.json\"
#define COROBS_LINK_LIBRARIES \"$<TARGET_PROPERTY:corobs,LINK_LIBRARIES>\"
#define COROBS_INTERFACE_LINK_LIBRARIES \"$<TARGET_PROPERTY:corobs,INTERFACE_LINK_LIBRARIES>\"
")

target_include_directories(corobs_tests PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(corobs_tests PRIVATE corobs::corobs GTest::gtest_main nlohmann_json::nlohmann_json)
if(MSVC)
  target_compile_options(corobs_tests PRIVATE /utf-8 /bigobj)
endif()

include(GoogleTest)
gtest_discover_tests(corobs_tests DISCOVERY_MODE PRE_TEST)

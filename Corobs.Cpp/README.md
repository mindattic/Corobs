# Corobs for C++

A C++20 port of [Corobs](../README.md), Correlithm Object technology after Lawrence's *Correlithm
Object Technology* (2004). It reproduces the C# reference bit for bit under the same seed, checked
against the shared [conformance vectors](../conformance/README.md). The library links nothing.

| Header | Holds |
|---|---|
| `corobs/geometry.hpp` | `NCube` statistics (Table II-1, Eq. III-H/J/Q), `Correlithm` points |
| `corobs/seeding.hpp` | `SeededPrng`: xoshiro256** under one seed, `derive(label)` child streams |
| `corobs/strings.hpp` | `StringCo`: line, ring and plane string COs |
| `corobs/converters.hpp` | cardinal, ordinal, continuous (line or ring) and planar converters |
| `corobs/mining.hpp` | `PatternMiner`, `RuleMiner`, `Cue` |
| `corobs/bench.hpp` | `Bench`: hold-out recall, reach, cascade yield |
| `corobs/corobs.hpp` | all of the above |

## Use it

```cmake
include(FetchContent)
FetchContent_Declare(corobs GIT_REPOSITORY https://github.com/mindattic/Corobs.git GIT_TAG main SOURCE_SUBDIR Corobs.Cpp)
FetchContent_MakeAvailable(corobs)          # or: add_subdirectory(path/to/Corobs/Corobs.Cpp)
target_link_libraries(app PRIVATE corobs::corobs)
```

Tests are built only when Corobs.Cpp is the top-level project (`COROBS_BUILD_TESTS`).

```cpp
#include <corobs/corobs.hpp>
using namespace corobs;

seeding::SeededPrng root(2004);
converters::CardinalConverter<std::string> faction(root.derive("faction"), 64);
auto a = faction.convert(std::string("Underclan"));
auto b = faction.convert(std::string("Arcturus"));
double bits = geometry::NCube::bit_content(64, a.distance_to(b));   // ~0: strangers at standard distance
```

Ids in `mining` and `bench` are any type with `std::hash`, `==` and `<`; `bench` also needs
`corobs::id_text<T>` (provided for integers and `std::string`, specialize it for your own ids),
because a pair's canonical order compares the ids' text ordinally, as the reference does. For
non-ASCII string ids that order is UTF-8 byte order, which differs from C#'s UTF-16 order only
between supplementary-plane characters and U+E000-U+FFFF.

## Build and test

```
cmake -S . -B build                 # fetches GoogleTest 1.15.2 and nlohmann/json 3.11.3 (tests only)
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

or from the repo root, `pwsh ./build.ps1 -Profile Cpp -Test`.

The library is compiled with `/fp:precise` (MSVC) or `-ffp-contract=off` (GCC/Clang) so no
multiply-add is fused; that is what keeps the coordinates identical to the reference.

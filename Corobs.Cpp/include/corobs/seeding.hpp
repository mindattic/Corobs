#pragma once

#include <cstdint>
#include <string_view>

namespace corobs::seeding {

/// A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed
/// yields the same doubles on every machine and in every language port of Corobs.
class SeededPrng {
public:
    /// A fresh stream seeded from `seed`.
    explicit SeededPrng(std::int64_t seed) noexcept;

    /// The root seed this stream (or derive chain) was built from.
    std::int64_t seed() const noexcept { return seed_; }

    /// A child stream named by `label` (hashed as UTF-8 bytes): the same parent seed and label always
    /// give the same child, independent of how many values the parent has produced.
    SeededPrng derive(std::string_view label) const noexcept;

    /// The next raw 64-bit word of the xoshiro256** stream.
    std::uint64_t next_uint64() noexcept;

    /// Uniform on [0, 1).
    double next_double() noexcept;

    /// Uniform integer on [0, max_exclusive); throws std::out_of_range when max_exclusive <= 0.
    int next(int max_exclusive);

private:
    std::uint64_t s0_, s1_, s2_, s3_;
    std::int64_t seed_;
};

}  // namespace corobs::seeding

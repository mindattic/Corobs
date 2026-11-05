#include "corobs/seeding.hpp"

#include <stdexcept>

namespace corobs::seeding {
namespace {

std::uint64_t rotl(std::uint64_t x, int k) noexcept { return (x << k) | (x >> (64 - k)); }

std::uint64_t split_mix(std::uint64_t& x) noexcept {
    x += 0x9E3779B97F4A7C15ULL;
    auto z = x;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

std::uint64_t fnv1a64(std::int64_t seed, std::string_view label) noexcept {
    std::uint64_t h = 14695981039346656037ULL;
    const auto s = static_cast<std::uint64_t>(seed);
    for (int i = 0; i < 8; ++i) {
        h ^= static_cast<std::uint8_t>(s >> (8 * i));
        h *= 1099511628211ULL;
    }
    for (char c : label) {
        h ^= static_cast<std::uint8_t>(c);
        h *= 1099511628211ULL;
    }
    return h;
}

}  // namespace

SeededPrng::SeededPrng(std::int64_t seed) noexcept : seed_(seed) {
    auto x = static_cast<std::uint64_t>(seed);
    s0_ = split_mix(x);
    s1_ = split_mix(x);
    s2_ = split_mix(x);
    s3_ = split_mix(x);
}

SeededPrng SeededPrng::derive(std::string_view label) const noexcept {
    return SeededPrng(static_cast<std::int64_t>(fnv1a64(seed_, label)));
}

std::uint64_t SeededPrng::next_uint64() noexcept {
    const auto result = rotl(s1_ * 5, 7) * 9;
    const auto t = s1_ << 17;
    s2_ ^= s0_;
    s3_ ^= s1_;
    s1_ ^= s2_;
    s0_ ^= s3_;
    s2_ ^= t;
    s3_ = rotl(s3_, 45);
    return result;
}

double SeededPrng::next_double() noexcept {
    return static_cast<double>(next_uint64() >> 11) * (1.0 / static_cast<double>(1ULL << 53));
}

int SeededPrng::next(int max_exclusive) {
    if (max_exclusive <= 0) throw std::out_of_range("max_exclusive must be positive.");
    return static_cast<int>(next_double() * max_exclusive);
}

}  // namespace corobs::seeding

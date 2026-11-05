#include <gtest/gtest.h>

#include <cstdint>
#include <vector>

#include "corobs/seeding.hpp"

using corobs::seeding::SeededPrng;

namespace {

TEST(SeededPrng, SameSeedSameStream) {
    SeededPrng a(42), b(42);
    for (int i = 0; i < 1000; ++i) ASSERT_EQ(a.next_uint64(), b.next_uint64());
}

TEST(SeededPrng, DifferentSeedsDiffer) {
    SeededPrng a(1), b(2);
    std::vector<std::uint64_t> xs, ys;
    for (int i = 0; i < 16; ++i) {
        xs.push_back(a.next_uint64());
        ys.push_back(b.next_uint64());
    }
    EXPECT_NE(xs, ys);
}

TEST(SeededPrng, DoublesAreUniformOnTheUnitInterval) {
    SeededPrng p(99);
    double sum = 0;
    for (int i = 0; i < 20000; ++i) {
        const double x = p.next_double();
        ASSERT_GE(x, 0.0);
        ASSERT_LT(x, 1.0);
        sum += x;
    }
    EXPECT_NEAR(sum / 20000, 0.5, 0.01);
}

TEST(SeededPrng, DeriveIsDeterministicAndIndependentOfConsumption) {
    SeededPrng a(5);
    a.next_uint64();
    a.next_uint64();
    SeededPrng b(5);
    EXPECT_EQ(a.derive("faction").seed(), b.derive("faction").seed());
    EXPECT_NE(a.derive("faction").seed(), b.derive("turf").seed());
    EXPECT_NE(a.derive("faction").seed(), a.seed());
}

TEST(SeededPrng, NextRejectsNonPositiveBounds) {
    SeededPrng p(1);
    EXPECT_THROW(p.next(0), std::out_of_range);
    EXPECT_THROW(p.next(-3), std::out_of_range);
}

}  // namespace

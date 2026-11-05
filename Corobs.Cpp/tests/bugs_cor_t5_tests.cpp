// COR-T5 is a decision, not a proven error (docs/BUGS.md): this pins the chosen behaviour.
#include <gtest/gtest.h>

#include <limits>

#include "corobs/converters.hpp"

using corobs::converters::ContinuousConverter;
using corobs::seeding::SeededPrng;

namespace {

class WrappingInfinity : public ::testing::TestWithParam<double> {};

TEST_P(WrappingInfinity, DecisionAWrappingConverterMapsInfinityToMissing) {
    SeededPrng prng(1);
    ContinuousConverter hours(prng, 32, 0, 24, true);
    EXPECT_EQ(hours.convert(GetParam()), hours.missing());
}

INSTANTIATE_TEST_SUITE_P(Infinity, WrappingInfinity,
                         ::testing::Values(std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity()));

}  // namespace

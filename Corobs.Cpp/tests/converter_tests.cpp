#include <gtest/gtest.h>

#include <cmath>
#include <limits>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "corobs/converters.hpp"

using corobs::converters::CardinalConverter;
using corobs::converters::ContinuousConverter;
using corobs::converters::OrdinalConverter;
using corobs::converters::PlanarConverter;
using corobs::geometry::Correlithm;
using corobs::geometry::NCube;
using corobs::seeding::SeededPrng;

namespace {

constexpr int N = 128;

TEST(Converters, CardinalValuesAreFixedTokensAtStandardDistanceFromEachOther) {
    CardinalConverter<std::string> c(SeededPrng(1), N);
    CardinalConverter<std::string> again(SeededPrng(1), N);
    const auto first = c.convert(std::string("Underclan"));
    EXPECT_EQ(c.convert(std::string("Underclan")), first) << "a value is one token, cached";
    EXPECT_EQ(again.convert(std::string("Underclan")), first) << "same seed, same token";
    const double mu = NCube::standard_distance(N);
    EXPECT_NEAR(c.convert(std::string("Underclan")).distance_to(c.convert(std::string("Arcturus"))) / mu, 1, 0.2);
    EXPECT_EQ(c.convert(std::nullopt), Correlithm::midpoint(N));
}

TEST(Converters, OrdinalNeighboursAreCloserThanExtremesAndUnknownsThrow) {
    const std::vector<std::string> tiers{"street", "runner", "fixer", "corpo", "board"};
    SeededPrng prng(2);
    OrdinalConverter<std::string> c(prng, N, tiers);
    const auto street = c.convert(std::string("street"));
    EXPECT_LT(street.distance_to(c.convert(std::string("runner"))), street.distance_to(c.convert(std::string("board"))));
    EXPECT_THROW(c.convert(std::string("god")), std::invalid_argument);
    EXPECT_EQ(c.convert(std::nullopt), c.missing());
    EXPECT_EQ(c.count(), 5);
}

TEST(Converters, OrdinalRejectsEmptyAndDuplicateOrders) {
    SeededPrng prng(2);
    EXPECT_THROW((OrdinalConverter<std::string>(prng, N, {})), std::invalid_argument);
    EXPECT_THROW((OrdinalConverter<std::string>(prng, N, {"a", "a"})), std::invalid_argument);
}

TEST(Converters, ContinuousValuesInterpolateAndCanWrap) {
    SeededPrng p3(3);
    ContinuousConverter years(p3, N, 2200, 2300);
    EXPECT_LT(years.convert(2230.0).distance_to(years.convert(2231.0)), years.convert(2230.0).distance_to(years.convert(2290.0)));
    EXPECT_EQ(years.convert(std::nullopt), years.missing());
    EXPECT_EQ(years.convert(std::numeric_limits<double>::quiet_NaN()), years.missing());

    SeededPrng p4(4);
    ContinuousConverter hours(p4, N, 0, 24, true);
    EXPECT_LT(hours.convert(23.5).distance_to(hours.convert(0.5)), hours.convert(23.5).distance_to(hours.convert(12.0)));

    SeededPrng p5(5);
    EXPECT_THROW(ContinuousConverter(p5, N, 1, 1), std::invalid_argument);
}

TEST(Converters, PlanarPositionsAreNearWhenTheMapSaysSo) {
    SeededPrng prng(5);
    PlanarConverter map(prng, N, -10, 10, -10, 10);
    const auto here = map.convert(std::pair{0.0, 0.0});
    EXPECT_LT(here.distance_to(map.convert(std::pair{0.5, 0.5})), here.distance_to(map.convert(std::pair{8.0, -7.0})));
    EXPECT_EQ(map.convert(std::nullopt), map.missing());
}

}  // namespace

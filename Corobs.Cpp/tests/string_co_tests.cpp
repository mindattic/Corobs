// Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at mu.
#include <gtest/gtest.h>

#include <cmath>

#include "corobs/strings.hpp"

using corobs::geometry::Correlithm;
using corobs::geometry::NCube;
using corobs::seeding::SeededPrng;
using corobs::strings::StringCo;

namespace {

constexpr int N = 2048;

TEST(StringCo, LineDistanceGrowsAsRootOfSeparationAndReachesMu) {
    SeededPrng prng(11);
    const auto line = StringCo::line(prng, N);
    const double mu = NCube::standard_distance(N);
    const auto origin = line.at(0);
    const double d1 = origin.distance_to(line.at(0.1));
    const double d3 = origin.distance_to(line.at(0.3));
    const double d6 = origin.distance_to(line.at(0.6));
    const double d10 = origin.distance_to(line.at(1.0));
    EXPECT_LT(d1, d3);
    EXPECT_LT(d3, d6);
    EXPECT_LT(d6, d10);
    EXPECT_NEAR(d1 / mu, std::sqrt(0.1), 0.06);
    EXPECT_NEAR(d10 / mu, 1, 0.06) << "the far ends are at standard distance";
    EXPECT_EQ(origin.distance_to(origin), 0);
}

TEST(StringCo, RingWraps) {
    SeededPrng prng(12);
    const auto ring = StringCo::ring(prng, N);
    const double mu = NCube::standard_distance(N);
    const auto origin = ring.at(0);
    EXPECT_NEAR(origin.distance_to(ring.at(0.5)) / mu, 1, 0.06) << "opposite side is mu";
    EXPECT_LT(origin.distance_to(ring.at(0.98)), origin.distance_to(ring.at(0.25))) << "0.98 is next to 0";
    EXPECT_EQ(ring.at(0.3).distance_to(ring.at(1.3)), 0) << "t is taken mod 1";
}

TEST(StringCo, PlaneIsIsotropic) {
    SeededPrng prng(13);
    const auto plane = StringCo::plane(prng, N);
    const auto origin = plane.at(0.5, 0.5);
    const double along_x = origin.distance_to(plane.at(0.8, 0.5));
    const double along_y = origin.distance_to(plane.at(0.5, 0.8));
    const double step = 0.3 / std::sqrt(2.0);
    const double diagonal = origin.distance_to(plane.at(0.5 + step, 0.5 + step));
    EXPECT_NEAR(along_x, along_y, along_y * 0.15);
    EXPECT_NEAR(diagonal, along_x, along_x * 0.2);
    EXPECT_LT(origin.distance_to(plane.at(0.55, 0.5)), along_x);
}

TEST(StringCo, EveryPositionIsAStrangerToAnUnrelatedPoint) {
    SeededPrng prng(14);
    const auto line = StringCo::line(prng, N);
    const auto stranger = Correlithm::random(prng, N);
    const double mu = NCube::standard_distance(N);
    for (double t : {0.0, 0.25, 0.5, 0.75, 1.0}) EXPECT_NEAR(line.at(t).distance_to(stranger) / mu, 1, 0.06);
}

TEST(StringCo, OrdinalPositionsAreEvenlySpaced) {
    SeededPrng prng(15);
    const auto line = StringCo::line(prng, N);
    const auto a = line.at_index(0, 26);
    const auto b = line.at_index(1, 26);
    const auto e = line.at_index(4, 26);
    const auto z = line.at_index(25, 26);
    EXPECT_LT(a.distance_to(b), a.distance_to(e));
    EXPECT_LT(a.distance_to(e), a.distance_to(z));
}

TEST(StringCo, SameSeedSameString) {
    SeededPrng p1(16), p2(16);
    EXPECT_EQ(StringCo::plane(p1, 64).at(0.2, 0.7), StringCo::plane(p2, 64).at(0.2, 0.7));
}

TEST(StringCo, WrongArityAndBadInputsThrow) {
    SeededPrng prng(17);
    const auto line = StringCo::line(prng, 8);
    const auto plane = StringCo::plane(prng, 8);
    EXPECT_THROW(line.at(0.1, 0.2), std::logic_error);
    EXPECT_THROW(plane.at(0.1), std::logic_error);
    EXPECT_THROW(line.at(std::nan("")), std::out_of_range);
    EXPECT_THROW(line.at_index(3, 3), std::out_of_range);
    EXPECT_THROW(StringCo::line(prng, 0), std::out_of_range);
}

}  // namespace

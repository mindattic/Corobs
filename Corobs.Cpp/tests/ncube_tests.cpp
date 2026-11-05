// Table II-1 and Ch. III, checked against the cube itself.
#include <gtest/gtest.h>

#include <cmath>
#include <numeric>
#include <vector>

#include "corobs/geometry.hpp"

using corobs::geometry::Correlithm;
using corobs::geometry::NCube;
using corobs::seeding::SeededPrng;

namespace {

double mean(const std::vector<double>& xs) { return std::accumulate(xs.begin(), xs.end(), 0.0) / static_cast<double>(xs.size()); }

class NCubeByN : public ::testing::TestWithParam<int> {};

TEST_P(NCubeByN, RandomPointsSitAtStandardDistanceWithTheBooksDeviation) {
    const int n = GetParam();
    SeededPrng prng(2004);
    std::vector<double> d(3000);
    for (auto& v : d) {
        auto a = Correlithm::random(prng, n);
        auto b = Correlithm::random(prng, n);
        v = a.distance_to(b);
    }
    const double m = mean(d);
    double ss = 0;
    for (double v : d) ss += (v - m) * (v - m);
    const double sd = std::sqrt(ss / static_cast<double>(d.size() - 1));
    EXPECT_NEAR(m, NCube::standard_distance(n), 0.03) << "mu = sqrt(N/6)";
    EXPECT_NEAR(sd, NCube::standard_deviation, 0.025) << "sigma = sqrt(7/120), independent of N";
}

TEST_P(NCubeByN, MidpointAndCornerDistancesMatchTheTable) {
    const int n = GetParam();
    SeededPrng prng(7);
    const auto mid = Correlithm::midpoint(n);
    const Correlithm corner(std::vector<double>(static_cast<std::size_t>(n), 0.0));
    std::vector<double> to_mid(2000), to_corner(2000);
    for (std::size_t i = 0; i < to_mid.size(); ++i) {
        auto p = Correlithm::random(prng, n);
        to_mid[i] = p.distance_to(mid);
        to_corner[i] = p.distance_to(corner);
    }
    EXPECT_NEAR(mean(to_mid), NCube::standard_radius(n), 0.02);
    EXPECT_NEAR(mean(to_corner), NCube::standard_diameter(n), 0.03);
    EXPECT_NEAR(NCube::half_diagonal(n), mid.distance_to(corner), 1e-12);
}

INSTANTIATE_TEST_SUITE_P(N, NCubeByN, ::testing::Values(64, 100));

TEST(NCube, BitContentFollowsEquationIIIH) {
    const int n = 100;
    const double mu = NCube::standard_distance(n);
    EXPECT_EQ(NCube::bit_content(n, mu), 0);
    EXPECT_EQ(NCube::bit_content(n, mu + 1), 0) << "beyond mu carries nothing";
    EXPECT_NEAR(NCube::bit_content(n, mu - 1), 24.75, 0.1);
    EXPECT_NEAR(NCube::bit_content(n, 0) / n, 4.12, 0.02);
    EXPECT_NEAR(NCube::distance_for_bits(n, 24.75), mu - 1, 0.005);
}

TEST(NCube, ProbabilityOfProximityIsTwoToTheMinusBits) {
    const int n = 100;
    const double mu = NCube::standard_distance(n);
    EXPECT_EQ(NCube::probability_of_proximity(n, mu), 1);
    EXPECT_NEAR(std::log10(NCube::probability_of_proximity(n, mu - 0.5)), -1.86, 0.02);
}

TEST(NCube, PointCapacityFollowsEquationIIIQ) {
    EXPECT_NEAR(std::log10(NCube::point_capacity(96, 1.0)), 33.3, 0.3);
    EXPECT_EQ(NCube::point_capacity(96, NCube::standard_distance(96)), 1);
}

TEST(NCube, DeviationsAndDistancesRoundTrip) {
    const int n = 64;
    const double d = NCube::distance_at_deviations(n, 6);
    EXPECT_NEAR(NCube::deviations_below(n, d), 6, 1e-9);
    EXPECT_NEAR(NCube::bit_content(n, d), 36 / std::log(2.0), 1e-9) << "6 sigma ~ 52 bits";
}

TEST(NCube, NonPositiveDimensionsThrow) {
    EXPECT_THROW(NCube::standard_distance(0), std::out_of_range);
    EXPECT_THROW(Correlithm::midpoint(-1), std::out_of_range);
    EXPECT_THROW(NCube::distance_for_bits(10, -1), std::out_of_range);
}

}  // namespace

#include <gtest/gtest.h>

#include <algorithm>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "corobs/mining.hpp"

using corobs::geometry::Correlithm;
using corobs::geometry::NCube;
using corobs::mining::Cue;
using corobs::mining::PatternMiner;
using corobs::mining::PlyPoint;
using corobs::mining::RuleMiner;
using corobs::seeding::SeededPrng;

namespace {

constexpr int N = 64;

Correlithm near(const Correlithm& centre, SeededPrng& prng, double jitter) {
    std::vector<double> c(static_cast<std::size_t>(centre.dimensions()));
    for (int i = 0; i < centre.dimensions(); ++i)
        c[static_cast<std::size_t>(i)] = std::clamp(centre[i] + (prng.next_double() - 0.5) * 2 * jitter, 0.0, 1.0);
    return Correlithm(c);
}

TEST(Mining, APlantedClusterAmongRandomPointsIsTheOnlyPattern) {
    SeededPrng prng(100);
    std::vector<PlyPoint<int>> points;
    for (int i = 0; i < 1000; ++i) points.push_back({i, Correlithm::random(prng, N)});
    const auto centre = Correlithm::random(prng, N);
    for (int i = 1000; i < 1006; ++i) points.push_back({i, near(centre, prng, 0.05)});

    const auto patterns = PatternMiner(6, 5).mine(points);

    ASSERT_EQ(patterns.size(), 1u);
    auto members = patterns[0].members();
    std::sort(members.begin(), members.end());
    EXPECT_EQ(members, (std::vector<int>{1000, 1001, 1002, 1003, 1004, 1005}));
    EXPECT_GT(patterns[0].bits(), NCube::bit_content(N, NCube::distance_at_deviations(N, 6)));
    EXPECT_LT(patterns[0].radius(), patterns[0].mean_pair_distance());
}

TEST(Mining, RandomPointsAloneYieldNoPattern) {
    SeededPrng prng(101);
    std::vector<PlyPoint<int>> points;
    for (int i = 0; i < 1500; ++i) points.push_back({i, Correlithm::random(prng, N)});
    EXPECT_TRUE(PatternMiner().mine(points).empty());
}

TEST(Mining, MiningIsDeterministic) {
    auto make = [] {
        SeededPrng p(102);
        std::vector<PlyPoint<int>> pts;
        for (int i = 0; i < 300; ++i) pts.push_back({i, i < 8 ? near(Correlithm::midpoint(N), p, 0.05) : Correlithm::random(p, N)});
        return pts;
    };
    const auto a = PatternMiner().mine(make());
    const auto b = PatternMiner().mine(make());
    ASSERT_EQ(a.size(), b.size());
    for (std::size_t i = 0; i < a.size(); ++i) {
        EXPECT_EQ(a[i].members(), b[i].members());
        EXPECT_EQ(a[i].bits(), b[i].bits());
    }
}

TEST(Mining, ARuleEmergesAndTheOneMemberThatBreaksItIsTheTopHit) {
    SeededPrng prng(103);
    const auto cs = Correlithm::random(prng, N);
    const auto ct = Correlithm::random(prng, N);

    std::vector<PlyPoint<int>> s, t;
    for (int id = 1; id <= 10; ++id) s.push_back({id, near(cs, prng, 0.05)});
    for (int id = 1; id <= 9; ++id) t.push_back({id, near(ct, prng, 0.05)});
    t.push_back({10, Correlithm::random(prng, N)});
    for (int id = 11; id <= 40; ++id) {
        s.push_back({id, Correlithm::random(prng, N)});
        t.push_back({id, Correlithm::random(prng, N)});
    }

    const PatternMiner miner;
    const auto ps = miner.mine(s);
    const auto pt = miner.mine(t);
    ASSERT_EQ(ps.size(), 1u);
    ASSERT_EQ(pt.size(), 1u);

    const auto rules = RuleMiner(0.8).mine<int>("faction", ps, "turf", pt);
    ASSERT_EQ(rules.size(), 1u);
    EXPECT_NEAR(rules[0].support, 0.9, 1e-9);

    std::map<std::string, std::unordered_map<int, Correlithm>> plies;
    for (const auto& p : s) plies["faction"].emplace(p.id, p.point);
    for (const auto& p : t) plies["turf"].emplace(p.id, p.point);
    const auto hits = Cue().find(rules, plies);
    ASSERT_EQ(hits.size(), 1u);
    EXPECT_EQ(hits[0].id, 10);
    EXPECT_EQ(hits[0].rank, 1);
    EXPECT_GT(hits[0].bits, 0);
    EXPECT_GT(hits[0].target_distance, NCube::distance_at_deviations(N, 1));
}

TEST(Mining, ARuleNeedsSupport) {
    SeededPrng prng(104);
    const auto cs = Correlithm::random(prng, N);
    const auto ct = Correlithm::random(prng, N);
    std::vector<PlyPoint<int>> s, t;
    for (int id = 1; id <= 10; ++id) s.push_back({id, near(cs, prng, 0.05)});
    for (int id = 1; id <= 5; ++id) t.push_back({id, near(ct, prng, 0.05)});
    for (int id = 6; id <= 10; ++id) t.push_back({id, Correlithm::random(prng, N)});
    const PatternMiner miner;
    EXPECT_TRUE(RuleMiner(0.8).mine<int>("a", miner.mine(s), "b", miner.mine(t)).empty()) << "half the members is not a rule";
    EXPECT_THROW(RuleMiner().mine<int>("a", miner.mine(s), "a", miner.mine(t)), std::invalid_argument);
}

TEST(Mining, ParametersAreValidated) {
    EXPECT_THROW(PatternMiner(0), std::out_of_range);
    EXPECT_THROW(PatternMiner(6, 1), std::out_of_range);
    EXPECT_THROW(RuleMiner(0), std::out_of_range);
    EXPECT_THROW(RuleMiner(1.5), std::out_of_range);
    EXPECT_THROW(Cue(-1), std::out_of_range);
}

}  // namespace

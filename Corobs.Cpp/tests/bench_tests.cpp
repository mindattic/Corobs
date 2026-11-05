#include <gtest/gtest.h>

#include <map>
#include <string>
#include <utility>
#include <vector>

#include "corobs/bench.hpp"

using corobs::bench::Bench;

namespace {

TEST(Bench, HoldoutRecallCountsHiddenPairsThePredictorRecovers) {
    std::vector<std::pair<std::string, std::string>> pairs;
    for (int i = 0; i < 20; ++i) pairs.emplace_back("a" + std::to_string(i), "b" + std::to_string(i));
    std::map<std::string, std::vector<std::string>> all;
    for (const auto& [a, b] : pairs) {
        all[a].push_back(b);
        all[b].push_back(a);
    }
    auto oracle = [&](const std::string& id) {
        auto it = all.find(id);
        return it == all.end() ? std::vector<std::string>{} : it->second;
    };
    auto blind = [](const std::string&) { return std::vector<std::string>{}; };

    const auto perfect = Bench::holdout_recall(pairs, 0.25, 1, oracle);
    EXPECT_EQ(perfect.hidden, 5);
    EXPECT_EQ(perfect.recall(), 1);
    EXPECT_EQ(perfect.precision(), 1);
    const auto nothing = Bench::holdout_recall(pairs, 0.25, 1, blind);
    EXPECT_EQ(nothing.recall(), 0);
    EXPECT_EQ(Bench::holdout_recall(pairs, 0.25, 1, blind).hidden, nothing.hidden);
    EXPECT_THROW(Bench::holdout_recall(pairs, 1.0, 1, blind), std::out_of_range);
}

TEST(Bench, ReachCountsHopsAndIsolatedRecords) {
    std::map<int, std::vector<int>> adj{{1, {2}}, {2, {1, 3}}, {3, {2}}, {4, {}}};
    const auto r = Bench::reach(std::vector<int>{1, 2, 3, 4}, [&](int id) { return adj[id]; }, 2);
    EXPECT_EQ(r.isolated, 1);
    EXPECT_EQ(r.total, 4);
    EXPECT_EQ(r.mean_reachable_by_hop[0], (1 + 2 + 1 + 0) / 4.0);
    EXPECT_EQ(r.mean_reachable_by_hop[1], (2 + 2 + 2 + 0) / 4.0);
    EXPECT_THROW(Bench::reach(std::vector<int>{1}, [&](int id) { return adj[id]; }, 0), std::out_of_range);
}

TEST(Bench, CascadeYieldIsClosedByCascadePerDirectFix) {
    EXPECT_EQ(Bench::cascade_yield(6, 4), 1.5);
    EXPECT_EQ(Bench::cascade_yield(0, 0), 0);
}

}  // namespace

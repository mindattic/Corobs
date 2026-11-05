// COR-T4 invariants (docs/BUGS.md). The reference keeps the old code behind symbols; this port
// carries the fixed behaviour only, so these tests pin the invariants and pass.
#include <gtest/gtest.h>

#include <algorithm>
#include <cctype>
#include <limits>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "corobs/bench.hpp"
#include "corobs/mining.hpp"
#include "corobs/strings.hpp"

using corobs::bench::Bench;
using corobs::geometry::Correlithm;
using corobs::geometry::NCube;
using corobs::mining::PatternMiner;
using corobs::mining::PlyPoint;
using corobs::seeding::SeededPrng;
using corobs::strings::StringCo;

namespace {

TEST(COR_T4, ThresholdNoPatternMemberIsLinkedByAPairShortOfTheRequiredSigma) {
    const int n = 4;
    const PatternMiner miner(6, 5);
    ASSERT_LT(NCube::distance_at_deviations(n, miner.min_deviations()), 0) << "precondition: mu - 6 sigma < 0 at N = 4";

    std::vector<PlyPoint<int>> points;
    for (int k = 0; k < 5; ++k) points.push_back({k, Correlithm{0.1 * k, 0.5, 0.5, 0.5}});

    for (const auto& pattern : miner.mine(points))
        for (int id : pattern.members()) {
            const auto& p = points[static_cast<std::size_t>(id)].point;
            double best = -std::numeric_limits<double>::infinity();
            for (int o : pattern.members())
                if (o != id) best = std::max(best, NCube::deviations_below(n, p.distance_to(points[static_cast<std::size_t>(o)].point)));
            EXPECT_GE(best, miner.min_deviations()) << "member " << id << " joined a pattern though its closest partner is only "
                                                     << best << " sigma below mu";
        }
}

class RingAtInfinity : public ::testing::TestWithParam<double> {};

TEST_P(RingAtInfinity, RingAtNeverReturnsAPointOffTheRing) {
    const int n = 32;
    SeededPrng prng(42);
    const auto ring = StringCo::ring(prng, n);
    const double t = GetParam();

    std::optional<Correlithm> p;
    try {
        p = ring.at(t);
    } catch (const std::out_of_range&) {
        return;
    }

    std::unordered_set<Correlithm> on_ring;
    const int steps = 200000;
    for (int k = 0; k < steps; ++k) on_ring.insert(ring.at(k / static_cast<double>(steps)));
    ASSERT_EQ(on_ring.size(), static_cast<std::size_t>(2 * n)) << "precondition: the grid visits every ring point";
    EXPECT_TRUE(on_ring.count(*p)) << "At(" << t << ") returned a point the ring never visits (Ch. IX, p. 123)";
}

INSTANTIATE_TEST_SUITE_P(Infinity, RingAtInfinity,
                         ::testing::Values(std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity()));

template <class T, class Hash = std::hash<T>, class Eq = std::equal_to<T>>
auto oracle(const std::vector<std::pair<T, T>>& pairs, Hash hash = {}, Eq eq = {}) {
    std::unordered_map<T, std::vector<T>, Hash, Eq> map(0, hash, eq);
    for (const auto& [a, b] : pairs) {
        map[a].push_back(b);
        map[b].push_back(a);
    }
    return [map](const T& id) {
        auto it = map.find(id);
        return it == map.end() ? std::vector<T>{} : it->second;
    };
}

TEST(COR_T4, PairsAPerfectPredictorRecoversEveryHiddenRelationshipEvenWhenListedRepeatedly) {
    std::vector<std::pair<int, int>> pairs;
    for (int i = 0; i < 20; ++i) {
        pairs.emplace_back(2 * i, 2 * i + 1);
        pairs.emplace_back(2 * i, 2 * i + 1);
        pairs.emplace_back(2 * i + 1, 2 * i);
    }
    const auto r = Bench::holdout_recall(pairs, 0.5, 7, oracle(pairs));
    EXPECT_EQ(r.recall(), 1.0) << "hidden " << r.hidden << ", recovered " << r.recovered;
}

std::string fold(const std::string& s) {
    std::string out(s);
    std::transform(out.begin(), out.end(), out.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return out;
}

struct IgnoreCaseHash {
    std::size_t operator()(const std::string& s) const { return std::hash<std::string>{}(fold(s)); }
};
struct IgnoreCaseEq {
    bool operator()(const std::string& a, const std::string& b) const { return fold(a) == fold(b); }
};

TEST(COR_T4, PairsOneRelationshipUnderTheCallersComparerIsHiddenOnce) {
    std::vector<std::pair<std::string, std::string>> pairs;
    for (int i = 0; i < 20; ++i) {
        pairs.emplace_back("a" + std::to_string(i), "B" + std::to_string(i));
        pairs.emplace_back("b" + std::to_string(i), "A" + std::to_string(i));
    }
    const auto r = Bench::holdout_recall(pairs, 0.5, 7, oracle(pairs, IgnoreCaseHash{}, IgnoreCaseEq{}), IgnoreCaseHash{}, IgnoreCaseEq{});
    EXPECT_EQ(r.hidden, 10) << "20 relationships, half hidden; each spelled two ways is still one relationship";
}

}  // namespace

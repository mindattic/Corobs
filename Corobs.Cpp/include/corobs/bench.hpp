#pragma once

#include <cmath>
#include <cstdint>
#include <functional>
#include <stdexcept>
#include <unordered_set>
#include <utility>
#include <vector>

#include "corobs/id_text.hpp"
#include "corobs/seeding.hpp"

namespace corobs::bench {

/// How well a neighbour function recovers relationships that were hidden from it.
struct RecallResult {
    int hidden;
    int recovered;
    int predicted;
    int predicted_true;
    /// Share of the hidden pairs that the predictor recovered.
    double recall() const noexcept { return hidden == 0 ? 0 : recovered / static_cast<double>(hidden); }
    /// Share of the predictor's own guesses that were true anywhere in the full truth.
    double precision() const noexcept { return predicted == 0 ? 0 : predicted_true / static_cast<double>(predicted); }
};

/// Mean reachable count per hop, and how many things reach nothing at all.
struct ReachResult {
    std::vector<double> mean_reachable_by_hop;
    int isolated;
    int total;
};

/// Scores any way of relating things against any other on the same ground truth. Arithmetic over
/// ids only; the caller supplies the truth and the predictors.
class Bench {
public:
    /// Hide holdout_fraction of the distinct true relationships (by seed), ask the predictor for each
    /// hidden endpoint's neighbours, and count how many hidden pairs come back. A relationship is an
    /// unordered pair under (hash, eq); its canonical order compares id_text<TId> ordinally.
    template <class TId, class Neighbours, class Hash = std::hash<TId>, class Eq = std::equal_to<TId>>
    static RecallResult holdout_recall(const std::vector<std::pair<TId, TId>>& true_pairs, double holdout_fraction,
                                       std::int64_t seed, Neighbours&& neighbours, Hash hash = {}, Eq eq = {}) {
        if (holdout_fraction <= 0 || holdout_fraction >= 1) throw std::out_of_range("holdout_fraction must lie in (0, 1).");
        using Pair = std::pair<TId, TId>;
        const PairHash<TId, Hash> pair_hash{hash};
        const PairEq<TId, Eq> pair_eq{eq};
        using PairSet = std::unordered_set<Pair, PairHash<TId, Hash>, PairEq<TId, Eq>>;

        PairSet truth(0, pair_hash, pair_eq);
        for (const auto& p : true_pairs) truth.insert(canon(p));

        seeding::SeededPrng prng(seed);
        // COR-T4 (docs/BUGS.md): a pair listed twice, or both ways round, is one relationship to hide.
        std::vector<Pair> shuffled;
        {
            PairSet distinct(0, pair_hash, pair_eq);
            for (const auto& p : true_pairs) {
                auto c = canon(p);
                if (distinct.insert(c).second) shuffled.push_back(std::move(c));
            }
        }
        for (std::size_t i = shuffled.size() - (shuffled.empty() ? 0 : 1); i > 0; --i) {
            const auto j = static_cast<std::size_t>(prng.next(static_cast<int>(i + 1)));
            std::swap(shuffled[i], shuffled[j]);
        }
        // Math.Round: half to even, as std::nearbyint does under the default rounding mode.
        const auto take = static_cast<std::size_t>(std::nearbyint(static_cast<double>(shuffled.size()) * holdout_fraction));
        std::vector<Pair> hidden;
        for (std::size_t i = 0; i < take && i < shuffled.size(); ++i) hidden.push_back(canon(shuffled[i]));
        PairSet hidden_set(hidden.begin(), hidden.end(), 0, pair_hash, pair_eq);

        int recovered = 0, predicted = 0, predicted_true = 0;
        std::vector<TId> endpoints;
        {
            std::unordered_set<TId, Hash, Eq> seen_ids(0, hash, eq);
            for (const auto& p : hidden) {
                if (seen_ids.insert(p.first).second) endpoints.push_back(p.first);
                if (seen_ids.insert(p.second).second) endpoints.push_back(p.second);
            }
        }
        PairSet seen(0, pair_hash, pair_eq);
        for (const auto& e : endpoints)
            for (const auto& nb : neighbours(e)) {
                auto pair = canon(Pair(e, nb));
                if (!seen.insert(pair).second) continue;
                ++predicted;
                if (truth.count(pair)) ++predicted_true;
                if (hidden_set.erase(pair)) ++recovered;
            }
        return RecallResult{static_cast<int>(hidden.size()), recovered, predicted, predicted_true};
    }

    /// Breadth-first reach from every id through `adjacency`, up to max_hops.
    template <class TId, class Adjacency, class Hash = std::hash<TId>, class Eq = std::equal_to<TId>>
    static ReachResult reach(const std::vector<TId>& ids, Adjacency&& adjacency, int max_hops, Hash hash = {}, Eq eq = {}) {
        if (max_hops <= 0) throw std::out_of_range("max_hops must be positive.");
        std::vector<double> sums(static_cast<std::size_t>(max_hops), 0.0);
        int isolated = 0;
        for (const auto& start : ids) {
            std::unordered_set<TId, Hash, Eq> visited(0, hash, eq);
            visited.insert(start);
            std::vector<TId> frontier{start};
            int reached = 0;
            for (int hop = 0; hop < max_hops; ++hop) {
                std::vector<TId> next;
                for (const auto& f : frontier)
                    for (const auto& a : adjacency(f))
                        if (visited.insert(a).second) next.push_back(a);
                reached += static_cast<int>(next.size());
                sums[static_cast<std::size_t>(hop)] += reached;
                frontier = std::move(next);
                if (frontier.empty()) {
                    for (int h = hop + 1; h < max_hops; ++h) sums[static_cast<std::size_t>(h)] += reached;
                    break;
                }
            }
            if (reached == 0) ++isolated;
        }
        std::vector<double> means;
        for (double s : sums) means.push_back(ids.empty() ? 0 : s / static_cast<double>(ids.size()));
        return ReachResult{std::move(means), isolated, static_cast<int>(ids.size())};
    }

    /// Hits closed because something else was fixed, per direct fix (0 when there were none).
    static double cascade_yield(int closed_by_cascade, int direct_fixes) noexcept {
        return direct_fixes == 0 ? 0 : closed_by_cascade / static_cast<double>(direct_fixes);
    }

private:
    template <class TId>
    static std::pair<TId, TId> canon(const std::pair<TId, TId>& p) {
        return id_text<TId>::get(p.first).compare(id_text<TId>::get(p.second)) <= 0 ? p : std::pair<TId, TId>(p.second, p.first);
    }

    // COR-T4 (docs/BUGS.md): unordered, so (a, b) and (b, a) are one pair under the caller's equality.
    template <class TId, class Hash>
    struct PairHash {
        Hash inner;
        std::size_t operator()(const std::pair<TId, TId>& p) const { return inner(p.first) ^ inner(p.second); }
    };
    template <class TId, class Eq>
    struct PairEq {
        Eq inner;
        bool operator()(const std::pair<TId, TId>& x, const std::pair<TId, TId>& y) const {
            return (inner(x.first, y.first) && inner(x.second, y.second)) || (inner(x.first, y.second) && inner(x.second, y.first));
        }
    };
};

}  // namespace corobs::bench

#pragma once

#include <algorithm>
#include <cstdio>
#include <functional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "corobs/geometry.hpp"

namespace corobs::mining {

/// One thing's position on one ply (subspace).
template <class TId>
struct PlyPoint {
    TId id;
    geometry::Correlithm point;
};

/// An emergent truth: things whose points on one ply lie far closer together than chance allows.
/// Proposed by PatternMiner; what it means, and whether it is true, is the caller's decision.
template <class TId>
class Pattern {
public:
    using Equality = std::function<bool(const TId&, const TId&)>;

    Pattern(std::vector<TId> members, geometry::Correlithm centroid, double radius, double mean_pair_distance,
            double bits, Equality equality = std::equal_to<TId>{})
        : members_(std::move(members)), centroid_(std::move(centroid)), radius_(radius),
          mean_pair_distance_(mean_pair_distance), bits_(bits),
          equality_(equality ? std::move(equality) : Equality(std::equal_to<TId>{})) {}

    /// The ids of the things in this cluster.
    const std::vector<TId>& members() const noexcept { return members_; }
    /// The mean point of the members.
    const geometry::Correlithm& centroid() const noexcept { return centroid_; }
    /// The furthest any member lies from the centroid.
    double radius() const noexcept { return radius_; }
    /// The mean distance between members, pairwise.
    double mean_pair_distance() const noexcept { return mean_pair_distance_; }
    /// Eq. III-H bits of the mean pair distance.
    double bits() const noexcept { return bits_; }

    /// Whether `id` is one of this pattern's members.
    bool contains(const TId& id) const {
        return std::any_of(members_.begin(), members_.end(), [&](const TId& m) { return equality_(m, id); });
    }

    /// "Pattern[k members, b bits]".
    std::string to_string() const {
        char buf[96];
        std::snprintf(buf, sizeof buf, "Pattern[%zu members, %.1f bits]", members_.size(), bits_);
        return buf;
    }

private:
    std::vector<TId> members_;
    geometry::Correlithm centroid_;
    double radius_, mean_pair_distance_, bits_;
    Equality equality_;
};

/// Finds the clusters on one ply that are far tighter than chance: two points are linked when they
/// lie at least min_deviations sigma below standard distance, linked points are joined by union-find,
/// and a component with at least min_members members is a proposed Pattern. Deterministic.
class PatternMiner {
public:
    explicit PatternMiner(double min_deviations = 6, int min_members = 5)
        : min_deviations_(min_deviations), min_members_(min_members) {
        if (min_deviations <= 0) throw std::out_of_range("min_deviations must be positive.");
        if (min_members < 2) throw std::out_of_range("min_members must be at least 2.");
    }

    double min_deviations() const noexcept { return min_deviations_; }
    int min_members() const noexcept { return min_members_; }

    /// The patterns among `points` (all on one ply), ordered by bits descending then by first member
    /// under `order`; `equality` is passed to each Pattern.
    template <class TId, class Compare = std::less<TId>>
    std::vector<Pattern<TId>> mine(const std::vector<PlyPoint<TId>>& points, Compare order = {},
                                   typename Pattern<TId>::Equality equality = std::equal_to<TId>{}) const {
        if (static_cast<int>(points.size()) < min_members_) return {};
        const int n = points[0].point.dimensions();
        std::vector<PlyPoint<TId>> sorted(points);
        std::stable_sort(sorted.begin(), sorted.end(),
                         [&](const PlyPoint<TId>& a, const PlyPoint<TId>& b) { return order(a.id, b.id); });
        const double threshold = geometry::NCube::distance_at_deviations(n, min_deviations_);
        // COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
        if (threshold < 0) return {};
        const double threshold_sq = threshold * threshold;

        const std::size_t count = sorted.size();
        std::vector<std::size_t> parent(count);
        for (std::size_t i = 0; i < count; ++i) parent[i] = i;
        for (std::size_t i = 0; i < count; ++i)
            for (std::size_t j = i + 1; j < count; ++j)
                if (sorted[i].point.squared_distance_to(sorted[j].point) <= threshold_sq) unite(parent, i, j);

        std::vector<std::size_t> roots;
        std::vector<std::vector<std::size_t>> groups;
        for (std::size_t i = 0; i < count; ++i) {
            const auto root = find(parent, i);
            auto it = std::find(roots.begin(), roots.end(), root);
            if (it == roots.end()) {
                roots.push_back(root);
                groups.push_back({i});
            } else {
                groups[static_cast<std::size_t>(it - roots.begin())].push_back(i);
            }
        }

        std::vector<Pattern<TId>> result;
        for (const auto& members : groups) {
            if (static_cast<int>(members.size()) < min_members_) continue;
            std::vector<geometry::Correlithm> pts;
            std::vector<TId> ids;
            for (auto i : members) {
                pts.push_back(sorted[i].point);
                ids.push_back(sorted[i].id);
            }
            auto centroid = geometry::Correlithm::centroid(pts);
            double radius = pts[0].distance_to(centroid);
            for (std::size_t k = 1; k < pts.size(); ++k) radius = std::max(radius, pts[k].distance_to(centroid));
            double sum = 0;
            int pairs = 0;
            for (std::size_t a = 0; a < pts.size(); ++a)
                for (std::size_t b = a + 1; b < pts.size(); ++b) {
                    sum += pts[a].distance_to(pts[b]);
                    ++pairs;
                }
            const double mean = sum / pairs;
            result.emplace_back(std::move(ids), std::move(centroid), radius, mean,
                                geometry::NCube::bit_content(n, mean), equality);
        }

        std::stable_sort(result.begin(), result.end(), [&](const Pattern<TId>& a, const Pattern<TId>& b) {
            if (a.bits() != b.bits()) return a.bits() > b.bits();
            return order(a.members()[0], b.members()[0]);
        });
        return result;
    }

private:
    static std::size_t find(std::vector<std::size_t>& parent, std::size_t i) {
        while (parent[i] != i) {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    }

    static void unite(std::vector<std::size_t>& parent, std::size_t a, std::size_t b) {
        const auto ra = find(parent, a);
        const auto rb = find(parent, b);
        if (ra == rb) return;
        if (ra < rb) parent[rb] = ra; else parent[ra] = rb;
    }

    double min_deviations_;
    int min_members_;
};

/// A rule s.p >: t.q (Ch. IV): things inside pattern `source` on ply `source_ply` are found inside
/// pattern `target` on ply `target_ply` with the given support.
template <class TId>
struct Rule {
    std::string source_ply;
    Pattern<TId> source;
    std::string target_ply;
    Pattern<TId> target;
    double support;
    double bits;

    std::string to_string() const {
        char buf[64];
        std::snprintf(buf, sizeof buf, "].[%zu] support %.0f%%, %.1f bits", target.members().size(), support * 100, bits);
        return source_ply + ".[" + std::to_string(source.members().size()) + "] >: " + target_ply + buf;
    }
};

/// Proposes rules between the patterns of two plies: for every source pattern, the target pattern
/// holding the largest share of its members, kept when that share reaches min_support.
/// bits = support * the source pattern's bits. Deterministic.
class RuleMiner {
public:
    explicit RuleMiner(double min_support = 0.8) : min_support_(min_support) {
        if (min_support <= 0 || min_support > 1) throw std::out_of_range("min_support must lie in (0, 1].");
    }

    double min_support() const noexcept { return min_support_; }

    /// The rules from source_ply's patterns to target_ply's that reach min_support, ordered by bits
    /// descending. Throws std::invalid_argument when the plies are the same.
    template <class TId>
    std::vector<Rule<TId>> mine(const std::string& source_ply, const std::vector<Pattern<TId>>& source,
                                const std::string& target_ply, const std::vector<Pattern<TId>>& target) const {
        if (source_ply == target_ply) throw std::invalid_argument("A rule relates two different plies.");
        std::vector<Rule<TId>> rules;
        for (const auto& p : source) {
            const Pattern<TId>* best = nullptr;
            std::size_t best_count = 0;
            for (const auto& q : target) {
                const auto count = static_cast<std::size_t>(
                    std::count_if(p.members().begin(), p.members().end(), [&](const TId& id) { return q.contains(id); }));
                if (count > best_count) {
                    best = &q;
                    best_count = count;
                }
            }
            if (best == nullptr) continue;
            const double support = static_cast<double>(best_count) / static_cast<double>(p.members().size());
            if (support >= min_support_) rules.push_back(Rule<TId>{source_ply, p, target_ply, *best, support, support * p.bits()});
        }
        std::stable_sort(rules.begin(), rules.end(), [](const Rule<TId>& a, const Rule<TId>& b) { return a.bits > b.bits; });
        return rules;
    }

private:
    double min_support_;
};

/// A ranked contradiction candidate: a thing inside a rule's source pattern that lies at or near
/// standard distance from the rule's target. What to do about it is the caller's decision.
template <class TId>
struct Hit {
    TId id;
    Rule<TId> rule;
    double source_distance;
    double target_distance;
    double bits;
    int rank;
};

/// For every rule, every member of its source whose target-ply point lies no closer than
/// target_deviations sigma below standard distance from the target centroid is a hit.
/// bits = (bits of the member's distance to the source centroid) * rule support. Deterministic.
class Cue {
public:
    explicit Cue(double target_deviations = 1) : target_deviations_(target_deviations) {
        if (target_deviations < 0) throw std::out_of_range("target_deviations must not be negative.");
    }

    double target_deviations() const noexcept { return target_deviations_; }

    /// `plies` maps a ply name to that ply's points by id (e.g. std::map<std::string,
    /// std::unordered_map<TId, Correlithm>>). Throws std::invalid_argument for a ply with no points.
    template <class TId, class Plies, class Compare = std::less<TId>>
    std::vector<Hit<TId>> find(const std::vector<Rule<TId>>& rules, const Plies& plies, Compare order = {}) const {
        std::vector<Hit<TId>> hits;
        for (const auto& rule : rules) {
            auto s = plies.find(rule.source_ply);
            if (s == plies.end()) throw std::invalid_argument("No points for ply '" + rule.source_ply + "'.");
            auto t = plies.find(rule.target_ply);
            if (t == plies.end()) throw std::invalid_argument("No points for ply '" + rule.target_ply + "'.");
            const auto& source_points = s->second;
            const auto& target_points = t->second;
            const int n = rule.target.centroid().dimensions();
            const double far_enough = geometry::NCube::distance_at_deviations(n, target_deviations_);
            for (const auto& id : rule.source.members()) {
                auto tp = target_points.find(id);
                if (tp == target_points.end()) continue;
                auto sp = source_points.find(id);
                if (sp == source_points.end()) continue;
                const double target_distance = tp->second.distance_to(rule.target.centroid());
                if (target_distance < far_enough) continue;
                const double source_distance = sp->second.distance_to(rule.source.centroid());
                const double bits = geometry::NCube::bit_content(sp->second.dimensions(), source_distance) * rule.support;
                hits.push_back(Hit<TId>{id, rule, source_distance, target_distance, bits, 0});
            }
        }
        std::stable_sort(hits.begin(), hits.end(), [&](const Hit<TId>& a, const Hit<TId>& b) {
            if (a.bits != b.bits) return a.bits > b.bits;
            return order(a.id, b.id);
        });
        for (std::size_t i = 0; i < hits.size(); ++i) hits[i].rank = static_cast<int>(i + 1);
        return hits;
    }

private:
    double target_deviations_;
};

}  // namespace corobs::mining

// conformance/vectors.json is the C# reference's exact output; this port must reproduce it
// (rules in conformance/README.md): hex strings bit for bit, JSON numbers to 1e-12 relative.
#include <gtest/gtest.h>

#include <algorithm>
#include <bit>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <map>
#include <nlohmann/json.hpp>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "corobs/corobs.hpp"
#include "corobs_test_config.hpp"

using json = nlohmann::json;
using namespace corobs;
using geometry::Correlithm;
using geometry::NCube;
using seeding::SeededPrng;

namespace {

const json& vectors() {
    static const json v = [] {
        std::ifstream in(COROBS_VECTORS_PATH);
        if (!in) throw std::runtime_error(std::string("cannot open ") + COROBS_VECTORS_PATH);
        return json::parse(in);
    }();
    return v;
}

double hex(const json& j) { return std::bit_cast<double>(static_cast<std::uint64_t>(std::stoull(j.get<std::string>(), nullptr, 16))); }
std::int64_t i64(const json& j) { return std::stoll(j.get<std::string>()); }
std::uint64_t u64(const json& j) { return std::stoull(j.get<std::string>()); }

std::vector<double> hexes(const json& j) {
    std::vector<double> out;
    for (const auto& x : j) out.push_back(hex(x));
    return out;
}

void expect_bits(const Correlithm& actual, const json& expected, const std::string& what) {
    const auto e = hexes(expected);
    ASSERT_EQ(actual.coordinates().size(), e.size()) << what;
    for (std::size_t i = 0; i < e.size(); ++i)
        EXPECT_EQ(std::bit_cast<std::uint64_t>(actual.coordinates()[i]), std::bit_cast<std::uint64_t>(e[i])) << what << " [" << i << "]";
}

void expect_bits(double actual, const json& expected, const std::string& what) {
    EXPECT_EQ(std::bit_cast<std::uint64_t>(actual), std::bit_cast<std::uint64_t>(hex(expected))) << what;
}

void expect_close(double actual, const json& expected, const std::string& what) {
    const double e = expected.get<double>();
    const double diff = std::abs(actual - e);
    EXPECT_TRUE(diff <= 1e-12 * std::max(std::abs(actual), std::abs(e)) || diff <= 1e-300)
        << what << ": " << actual << " vs " << e;
}

TEST(Conformance, Prng) {
    for (const auto& c : vectors()["prng"]) {
        const auto seed = i64(c["seed"]);
        SeededPrng u(seed), d(seed);
        for (const auto& x : c["uint64"]) EXPECT_EQ(u.next_uint64(), u64(x)) << "seed " << seed;
        for (const auto& x : c["doubles"]) expect_bits(d.next_double(), x, "double, seed " + std::to_string(seed));
        for (const auto& n : c["next"]) {
            SeededPrng p(seed);
            const int max = n["max"].get<int>();
            for (const auto& x : n["values"]) EXPECT_EQ(p.next(max), x.get<int>()) << "seed " << seed << " max " << max;
        }
    }
}

TEST(Conformance, Derive) {
    for (const auto& c : vectors()["derive"]) {
        const auto label = c["label"].get<std::string>();
        auto child = SeededPrng(i64(c["seed"])).derive(label);
        EXPECT_EQ(child.seed(), i64(c["childSeed"])) << label;
        EXPECT_EQ(child.next_uint64(), u64(c["firstUint64"])) << label;
        EXPECT_EQ(child.derive("x").seed(), i64(c["grandchildSeed"])) << label;
    }
}

TEST(Conformance, NCube) {
    const auto& v = vectors()["ncube"];
    expect_close(NCube::standard_deviation, v["standardDeviation"], "standardDeviation");
    expect_close(NCube::radius_deviation, v["radiusDeviation"], "radiusDeviation");
    expect_close(NCube::diameter_deviation, v["diameterDeviation"], "diameterDeviation");
    for (const auto& c : v["cases"]) {
        const int n = c["n"].get<int>();
        const auto at = "N=" + std::to_string(n) + " ";
        expect_close(NCube::standard_distance(n), c["standardDistance"], at + "standardDistance");
        expect_close(NCube::standard_radius(n), c["standardRadius"], at + "standardRadius");
        expect_close(NCube::standard_diameter(n), c["standardDiameter"], at + "standardDiameter");
        expect_close(NCube::corner_distance(n), c["cornerDistance"], at + "cornerDistance");
        expect_close(NCube::half_diagonal(n), c["halfDiagonal"], at + "halfDiagonal");
        expect_close(NCube::major_diagonal(n), c["majorDiagonal"], at + "majorDiagonal");
        for (const auto& d : c["distances"]) {
            const double dist = d["distance"].get<double>();
            expect_close(NCube::deviations_below(n, dist), d["deviationsBelow"], at + "deviationsBelow");
            expect_close(NCube::bit_content(n, dist), d["bitContent"], at + "bitContent");
            expect_close(NCube::probability_of_proximity(n, dist), d["probabilityOfProximity"], at + "probabilityOfProximity");
            expect_close(NCube::point_capacity(n, dist), d["pointCapacity"], at + "pointCapacity");
        }
        for (const auto& b : c["bitsToDistance"])
            expect_close(NCube::distance_for_bits(n, b["bits"].get<double>()), b["distanceForBits"], at + "distanceForBits");
        for (const auto& k : c["distanceAtDeviations"])
            expect_close(NCube::distance_at_deviations(n, k["deviations"].get<double>()), k["distance"], at + "distanceAtDeviations");
    }
}

TEST(Conformance, Correlithm) {
    const auto& v = vectors()["correlithm"];
    SeededPrng prng(i64(v["seed"]));
    const int n = v["dimensions"].get<int>();
    const auto a = Correlithm::random(prng, n);
    const auto b = Correlithm::random(prng, n);
    const auto mid = Correlithm::midpoint(n);
    expect_bits(a, v["a"], "a");
    expect_bits(b, v["b"], "b");
    expect_bits(mid, v["midpoint"], "midpoint");
    expect_bits(a.squared_distance_to(b), v["squaredDistance"], "squaredDistance");
    expect_bits(a.distance_to(b), v["distance"], "distance");
    expect_bits(Correlithm::centroid({a, b, mid}), v["centroidOfABMidpoint"], "centroid");
    for (const auto& f : v["interpolate"])
        expect_bits(a.interpolate(b, f["fraction"].get<double>()), f["point"], "interpolate");
}

TEST(Conformance, Strings) {
    const auto& v = vectors()["strings"];
    const int n = v["dimensions"].get<int>();
    SeededPrng pl(i64(v["line"]["seed"])), pr(i64(v["ring"]["seed"])), pp(i64(v["plane"]["seed"]));
    const auto line = strings::StringCo::line(pl, n);
    const auto ring = strings::StringCo::ring(pr, n);
    const auto plane = strings::StringCo::plane(pp, n);
    for (const auto& c : v["line"]["at"]) expect_bits(line.at(hex(c["t"])), c["point"], "line.at " + c["t"].get<std::string>());
    for (const auto& c : v["line"]["atIndex"]) expect_bits(line.at_index(c["index"].get<int>(), c["count"].get<int>()), c["point"], "line.at_index");
    for (const auto& c : v["line"]["atIndexSingle"]) expect_bits(line.at_index(c["index"].get<int>(), c["count"].get<int>()), c["point"], "line.at_index single");
    for (const auto& c : v["ring"]["at"]) expect_bits(ring.at(hex(c["t"])), c["point"], "ring.at " + c["t"].get<std::string>());
    for (const auto& c : v["ring"]["atIndex"]) expect_bits(ring.at_index(c["index"].get<int>(), c["count"].get<int>()), c["point"], "ring.at_index");
    for (const auto& c : v["plane"]["at"]) expect_bits(plane.at(hex(c["x"]), hex(c["y"])), c["point"], "plane.at");
}

TEST(Conformance, Converters) {
    const auto& v = vectors()["converters"];
    const int n = v["dimensions"].get<int>();

    converters::CardinalConverter<std::string> cardinal(SeededPrng(i64(v["cardinal"]["seed"])), n);
    for (const auto& c : v["cardinal"]["cases"])
        expect_bits(cardinal.convert(c["value"].get<std::string>()), c["point"], "cardinal " + c["value"].get<std::string>());
    expect_bits(cardinal.convert(std::nullopt), v["missing"], "cardinal missing");

    std::vector<std::string> order;
    for (const auto& o : v["ordinal"]["order"]) order.push_back(o.get<std::string>());
    SeededPrng po(i64(v["ordinal"]["seed"]));
    converters::OrdinalConverter<std::string> ordinal(po, n, order);
    for (const auto& c : v["ordinal"]["cases"]) expect_bits(ordinal.convert(c["value"].get<std::string>()), c["point"], "ordinal");

    for (const char* key : {"continuousLine", "continuousRing"}) {
        const auto& s = v[key];
        SeededPrng p(i64(s["seed"]));
        converters::ContinuousConverter conv(p, n, s["min"].get<double>(), s["max"].get<double>(), s["wraps"].get<bool>());
        for (const auto& c : s["cases"]) expect_bits(conv.convert(hex(c["value"])), c["point"], std::string(key) + " " + c["value"].get<std::string>());
    }

    const auto& pl = v["planar"];
    SeededPrng pp(i64(pl["seed"]));
    converters::PlanarConverter planar(pp, n, pl["minX"].get<double>(), pl["maxX"].get<double>(), pl["minY"].get<double>(), pl["maxY"].get<double>());
    for (const auto& c : pl["cases"]) expect_bits(planar.convert(std::pair{hex(c["x"]), hex(c["y"])}), c["point"], "planar");
}

TEST(Conformance, Mining) {
    const auto& v = vectors()["mining"];
    std::map<std::string, std::vector<mining::PlyPoint<int>>> points;
    std::map<std::string, std::unordered_map<int, Correlithm>> plies;
    for (const char* ply : {"faction", "turf"})
        for (const auto& p : v["plies"][ply]) {
            Correlithm point(hexes(p["point"]));
            points[ply].push_back({p["id"].get<int>(), point});
            plies[ply].emplace(p["id"].get<int>(), point);
        }

    const mining::PatternMiner miner(v["patternMiner"]["minDeviations"].get<double>(), v["patternMiner"]["minMembers"].get<int>());
    std::map<std::string, std::vector<mining::Pattern<int>>> patterns;
    for (const char* ply : {"faction", "turf"}) {
        patterns.emplace(ply, miner.mine(points[ply]));
        const auto& expected = v["patterns"][ply];
        const auto& actual = patterns.at(ply);
        ASSERT_EQ(actual.size(), expected.size()) << ply;
        for (std::size_t i = 0; i < actual.size(); ++i) {
            const auto& e = expected[i];
            EXPECT_EQ(actual[i].members(), e["members"].get<std::vector<int>>()) << ply << " pattern " << i;
            expect_bits(actual[i].centroid(), e["centroid"], "centroid");
            expect_bits(actual[i].radius(), e["radius"], "radius");
            expect_bits(actual[i].mean_pair_distance(), e["meanPairDistance"], "meanPairDistance");
            expect_close(actual[i].bits(), e["bits"], "pattern bits");
        }
    }

    const auto rules = mining::RuleMiner(v["ruleMiner"]["minSupport"].get<double>())
                           .mine<int>("faction", patterns.at("faction"), "turf", patterns.at("turf"));
    ASSERT_EQ(rules.size(), v["rules"].size());
    for (std::size_t i = 0; i < rules.size(); ++i) {
        const auto& e = v["rules"][i];
        EXPECT_EQ(rules[i].source_ply, e["sourcePly"].get<std::string>());
        EXPECT_EQ(rules[i].target_ply, e["targetPly"].get<std::string>());
        EXPECT_EQ(rules[i].source.members(), patterns.at("faction")[e["sourcePattern"].get<std::size_t>()].members());
        EXPECT_EQ(rules[i].target.members(), patterns.at("turf")[e["targetPattern"].get<std::size_t>()].members());
        expect_close(rules[i].support, e["support"], "support");
        expect_close(rules[i].bits, e["bits"], "rule bits");
    }

    const auto hits = mining::Cue(v["cue"]["targetDeviations"].get<double>()).find(rules, plies);
    ASSERT_EQ(hits.size(), v["hits"].size());
    for (std::size_t i = 0; i < hits.size(); ++i) {
        const auto& e = v["hits"][i];
        EXPECT_EQ(hits[i].id, e["id"].get<int>());
        EXPECT_EQ(hits[i].rule.source.members(), rules[e["rule"].get<std::size_t>()].source.members());
        expect_bits(hits[i].source_distance, e["sourceDistance"], "sourceDistance");
        expect_bits(hits[i].target_distance, e["targetDistance"], "targetDistance");
        expect_close(hits[i].bits, e["bits"], "hit bits");
        EXPECT_EQ(hits[i].rank, e["rank"].get<int>());
    }
}

TEST(Conformance, Bench) {
    const auto& v = vectors()["bench"];
    std::vector<std::pair<int, int>> pairs;
    for (const auto& p : v["pairs"]) pairs.emplace_back(p[0].get<int>(), p[1].get<int>());

    for (const auto& c : v["holdoutRecall"]) {
        const auto& table = v["predictors"][c["predictor"].get<std::string>()];
        auto predictor = [&](int id) {
            const auto key = std::to_string(id);
            return table.contains(key) ? table[key].get<std::vector<int>>() : std::vector<int>{};
        };
        const auto r = bench::Bench::holdout_recall(pairs, c["holdoutFraction"].get<double>(), i64(c["seed"]), predictor);
        const auto& e = c["result"];
        const auto what = c["predictor"].get<std::string>() + " " + c["seed"].get<std::string>();
        EXPECT_EQ(r.hidden, e["hidden"].get<int>()) << what;
        EXPECT_EQ(r.recovered, e["recovered"].get<int>()) << what;
        EXPECT_EQ(r.predicted, e["predicted"].get<int>()) << what;
        EXPECT_EQ(r.predicted_true, e["predictedTrue"].get<int>()) << what;
    }

    const auto& rc = v["reach"];
    std::vector<int> ids;
    std::map<int, std::vector<int>> adj;
    for (const auto& [key, list] : rc["adjacency"].items()) {
        ids.push_back(std::stoi(key));
        adj[std::stoi(key)] = list.get<std::vector<int>>();
    }
    const auto r = bench::Bench::reach(ids, [&](int id) { return adj[id]; }, rc["maxHops"].get<int>());
    ASSERT_EQ(r.mean_reachable_by_hop.size(), rc["meanReachableByHop"].size());
    for (std::size_t i = 0; i < r.mean_reachable_by_hop.size(); ++i)
        expect_close(r.mean_reachable_by_hop[i], rc["meanReachableByHop"][i], "meanReachableByHop");
    EXPECT_EQ(r.isolated, rc["isolated"].get<int>());
    EXPECT_EQ(r.total, rc["total"].get<int>());

    for (const auto& c : v["cascadeYield"])
        expect_close(bench::Bench::cascade_yield(c["closedByCascade"].get<int>(), c["directFixes"].get<int>()), c["yield"], "cascadeYield");
}

}  // namespace

#include "corobs/geometry.hpp"

#include <bit>
#include <cmath>
#include <cstdint>
#include <stdexcept>

namespace corobs::geometry {
namespace {

int check(int dimensions) {
    if (dimensions <= 0)
        throw std::out_of_range("A space needs at least one dimension; the statistics hold from about 20.");
    return dimensions;
}

}  // namespace

double NCube::standard_distance(int n) { return std::sqrt(check(n) / 6.0); }
double NCube::standard_radius(int n) { return std::sqrt(check(n) / 12.0); }
double NCube::standard_diameter(int n) { return std::sqrt(check(n) / 3.0); }
double NCube::corner_distance(int n) { return std::sqrt(check(n) / 2.0); }
double NCube::half_diagonal(int n) { return std::sqrt(check(n) / 4.0); }
double NCube::major_diagonal(int n) { return std::sqrt(static_cast<double>(check(n))); }

double NCube::deviations_below(int n, double distance) {
    return (standard_distance(n) - distance) / standard_deviation;
}

double NCube::distance_at_deviations(int n, double deviations) {
    return standard_distance(n) - deviations * standard_deviation;
}

double NCube::bit_content(int n, double distance) {
    const double x = deviations_below(n, distance);
    return x <= 0 ? 0 : x * x / std::log(2.0);
}

double NCube::distance_for_bits(int n, double bits) {
    if (bits < 0) throw std::out_of_range("bits must not be negative.");
    return standard_distance(n) - standard_deviation * std::sqrt(bits * std::log(2.0));
}

double NCube::probability_of_proximity(int n, double distance) {
    return std::pow(2.0, -bit_content(n, distance));
}

double NCube::point_capacity(int n, double distance) {
    const double gap = standard_distance(n) - distance;
    return gap <= 0 ? 1 : std::pow(10.0, 3.7 * gap * gap);
}

Correlithm::Correlithm(std::vector<double> coordinates) : c_(std::move(coordinates)) {
    if (c_.empty()) throw std::invalid_argument("A point needs at least one coordinate.");
    for (double v : c_)
        if (std::isnan(v) || v < 0 || v > 1) throw std::out_of_range("Every coordinate must lie in [0, 1].");
}

Correlithm::Correlithm(std::initializer_list<double> coordinates) : Correlithm(std::vector<double>(coordinates)) {}

Correlithm Correlithm::random(seeding::SeededPrng& prng, int dimensions) {
    std::vector<double> c(static_cast<std::size_t>(check(dimensions)));
    for (auto& v : c) v = prng.next_double();
    return Correlithm(owned_tag{}, std::move(c));
}

Correlithm Correlithm::midpoint(int dimensions) {
    return Correlithm(owned_tag{}, std::vector<double>(static_cast<std::size_t>(check(dimensions)), 0.5));
}

Correlithm Correlithm::centroid(const std::vector<Correlithm>& points) {
    if (points.empty()) throw std::invalid_argument("A centroid needs at least one point.");
    std::vector<double> sum(points[0].c_.size(), 0.0);
    for (const auto& p : points) {
        if (p.c_.size() != sum.size()) throw std::invalid_argument("All points must share one dimensionality.");
        for (std::size_t i = 0; i < sum.size(); ++i) sum[i] += p.c_[i];
    }
    for (auto& v : sum) v /= static_cast<double>(points.size());
    return Correlithm(owned_tag{}, std::move(sum));
}

double Correlithm::squared_distance_to(const Correlithm& other) const {
    check_same(other);
    double s = 0;
    for (std::size_t i = 0; i < c_.size(); ++i) {
        const double d = c_[i] - other.c_[i];
        const double sq = d * d;
        s += sq;
    }
    return s;
}

double Correlithm::distance_to(const Correlithm& other) const { return std::sqrt(squared_distance_to(other)); }

Correlithm Correlithm::interpolate(const Correlithm& other, double fraction) const {
    check_same(other);
    if (fraction < 0 || fraction > 1) throw std::out_of_range("fraction must lie in [0, 1].");
    std::vector<double> c(c_.size());
    for (std::size_t i = 0; i < c.size(); ++i) {
        const double step = (other.c_[i] - c_[i]) * fraction;
        c[i] = c_[i] + step;
    }
    return Correlithm(owned_tag{}, std::move(c));
}

std::size_t Correlithm::hash() const noexcept {
    std::uint64_t h = 14695981039346656037ULL;
    for (double v : c_) {
        h ^= std::bit_cast<std::uint64_t>(v == 0 ? 0.0 : v);
        h *= 1099511628211ULL;
    }
    return static_cast<std::size_t>(h);
}

std::string Correlithm::to_string() const { return "CO[" + std::to_string(c_.size()) + "]"; }

void Correlithm::check_same(const Correlithm& other) const {
    if (other.c_.size() != c_.size()) throw std::invalid_argument("Points from different spaces have no distance.");
}

}  // namespace corobs::geometry

#pragma once

#include <cstddef>
#include <functional>
#include <initializer_list>
#include <string>
#include <vector>

#include "corobs/seeding.hpp"

namespace corobs::geometry {

/// The statistics of the real unit N-cube (Lawrence, Correlithm Object Technology, Ch. II-III).
/// Two random points are almost always standard_distance apart, with a standard deviation that does
/// not grow with N (Table II-1). Valid for N of about 20 and up.
class NCube {
public:
    /// sigma of the distance between two random points: sqrt(7/120), independent of N.
    static constexpr double standard_deviation = 0.24152294576982397;
    /// sigma of the distance from the midpoint to a random point: sqrt(1/60).
    static constexpr double radius_deviation = 0.12909944487358055;
    /// sigma of the distance from a corner to a random point: sqrt(1/15).
    static constexpr double diameter_deviation = 0.2581988897471611;

    /// mu: expected distance between two random points, sqrt(N/6).
    static double standard_distance(int dimensions);
    /// Expected distance from the midpoint to a random point, sqrt(N/12).
    static double standard_radius(int dimensions);
    /// Expected distance from a corner to a random point, sqrt(N/3).
    static double standard_diameter(int dimensions);
    /// Expected distance between two random corners, sqrt(N/2).
    static double corner_distance(int dimensions);
    /// Midpoint to any corner, exactly sqrt(N/4).
    static double half_diagonal(int dimensions);
    /// Opposite corners, exactly sqrt(N).
    static double major_diagonal(int dimensions);
    /// How many standard deviations below mu a distance lies (negative beyond mu).
    static double deviations_below(int dimensions, double distance);
    /// The distance that lies `deviations` sigma below mu.
    static double distance_at_deviations(int dimensions, double deviations);
    /// Eq. III-H: bits of information in two points `distance` apart, ((mu - d)/sigma)^2 / ln 2.
    static double bit_content(int dimensions, double distance);
    /// The distance at which proximity is worth `bits` bits.
    static double distance_for_bits(int dimensions, double bits);
    /// Eq. III-J: probability that two random points lie closer than `distance`, 2^-bits.
    static double probability_of_proximity(int dimensions, double distance);
    /// Eq. III-Q: how many random points fit before two are expected closer than `distance`.
    static double point_capacity(int dimensions, double distance);
};

/// A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A soft
/// token (Ch. IV). Immutable.
class Correlithm {
public:
    /// A point at exactly these coordinates; each must lie in [0, 1].
    explicit Correlithm(std::vector<double> coordinates);
    Correlithm(std::initializer_list<double> coordinates);

    /// A point chosen uniformly at random from the whole cube.
    static Correlithm random(seeding::SeededPrng& prng, int dimensions);
    /// The cube's centre, 0.5 in every dimension: where a missing value goes.
    static Correlithm midpoint(int dimensions);
    /// The coordinate-wise mean of a set of points.
    static Correlithm centroid(const std::vector<Correlithm>& points);
    /// A point that superposes several: their centroid (Ch. VIII).
    static Correlithm superpose(const std::vector<Correlithm>& points) { return centroid(points); }

    /// N: the dimensionality of the cube this point lives in.
    int dimensions() const noexcept { return static_cast<int>(c_.size()); }
    /// The coordinate on one dimension.
    double operator[](int dimension) const { return c_.at(static_cast<std::size_t>(dimension)); }
    /// All N coordinates, in order.
    const std::vector<double>& coordinates() const noexcept { return c_; }

    /// Euclidean distance squared to a point from the same cube.
    double squared_distance_to(const Correlithm& other) const;
    /// Euclidean distance to a point from the same cube.
    double distance_to(const Correlithm& other) const;
    /// Linear interpolation by `fraction` toward `other` (Ch. VII: interpolated points take a
    /// shortcut; use StringCo for sequences).
    Correlithm interpolate(const Correlithm& other, double fraction) const;

    /// True when every coordinate matches exactly; not a proximity test.
    bool operator==(const Correlithm& other) const noexcept { return c_ == other.c_; }
    bool operator!=(const Correlithm& other) const noexcept { return !(*this == other); }
    /// Consistent with operator==.
    std::size_t hash() const noexcept;
    /// Just the dimensionality: "CO[N]".
    std::string to_string() const;

private:
    struct owned_tag {};
    Correlithm(owned_tag, std::vector<double> owned) noexcept : c_(std::move(owned)) {}
    void check_same(const Correlithm& other) const;

    std::vector<double> c_;
};

}  // namespace corobs::geometry

template <>
struct std::hash<corobs::geometry::Correlithm> {
    std::size_t operator()(const corobs::geometry::Correlithm& p) const noexcept { return p.hash(); }
};

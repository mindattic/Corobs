#pragma once

#include <vector>

#include "corobs/geometry.hpp"
#include "corobs/seeding.hpp"

namespace corobs::strings {

/// A string CO (Ch. VII): a line, a ring or a plane embedded in the N-cube so that distance along
/// the geometry becomes distance in the cube, while every position stays at standard distance from
/// unrelated points. Each dimension carries two random values and switches between them at its own
/// random breakpoint; no interpolation is involved.
class StringCo {
public:
    /// A line segment parameterised by t in [0, 1]. Distance between t and t' ~ mu * sqrt(|t - t'|).
    static StringCo line(seeding::SeededPrng& prng, int dimensions);
    /// A closed ring parameterised by t in [0, 1) with 0 == 1.
    static StringCo ring(seeding::SeededPrng& prng, int dimensions);
    /// A unit square parameterised by (x, y) in [0, 1]^2, isotropic (Fig. VII-10).
    static StringCo plane(seeding::SeededPrng& prng, int dimensions);

    /// N: the dimensionality of the cube this geometry is embedded in.
    int dimensions() const noexcept { return static_cast<int>(a_.size()); }

    /// The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1). Throws
    /// std::logic_error on a plane, std::out_of_range for NaN, and for +/-infinity on a ring.
    geometry::Correlithm at(double t) const;
    /// The point at (x, y) on a plane, each clamped to [0, 1].
    geometry::Correlithm at(double x, double y) const;
    /// The index-th of count evenly spaced positions (an ordinal set, Fig. VII-8).
    geometry::Correlithm at_index(int index, int count) const;

private:
    enum class Kind { Line, Ring, Plane };
    StringCo(Kind kind, std::vector<double> a, std::vector<double> b, std::vector<double> o,
             std::vector<double> dx, std::vector<double> dy);

    Kind kind_;
    std::vector<double> a_, b_, o_, dx_, dy_;
};

}  // namespace corobs::strings

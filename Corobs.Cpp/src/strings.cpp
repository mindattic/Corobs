#include "corobs/strings.hpp"

#include <algorithm>
#include <cmath>
#include <numbers>
#include <stdexcept>

namespace corobs::strings {
namespace {

using geometry::Correlithm;

// .NET Math.Min/Math.Max: -0 is below +0, unlike std::min/std::max.
double net_min(double a, double b) {
    if (a < b) return a;
    if (b < a) return b;
    return std::signbit(a) ? a : b;
}

double net_max(double a, double b) {
    if (a > b) return a;
    if (b > a) return b;
    return std::signbit(a) ? b : a;
}

void values(seeding::SeededPrng& prng, int dimensions, std::vector<double>& a, std::vector<double>& b) {
    if (dimensions <= 0) throw std::out_of_range("dimensions must be positive.");
    a.resize(static_cast<std::size_t>(dimensions));
    b.resize(static_cast<std::size_t>(dimensions));
    for (std::size_t i = 0; i < a.size(); ++i) {
        a[i] = prng.next_double();
        b[i] = prng.next_double();
    }
}

}  // namespace

StringCo::StringCo(Kind kind, std::vector<double> a, std::vector<double> b, std::vector<double> o,
                   std::vector<double> dx, std::vector<double> dy)
    : kind_(kind), a_(std::move(a)), b_(std::move(b)), o_(std::move(o)), dx_(std::move(dx)), dy_(std::move(dy)) {}

StringCo StringCo::line(seeding::SeededPrng& prng, int dimensions) {
    std::vector<double> a, b;
    values(prng, dimensions, a, b);
    std::vector<double> o(a.size());
    for (auto& v : o) v = prng.next_double();
    return StringCo(Kind::Line, std::move(a), std::move(b), std::move(o), {}, {});
}

StringCo StringCo::ring(seeding::SeededPrng& prng, int dimensions) {
    std::vector<double> a, b;
    values(prng, dimensions, a, b);
    std::vector<double> o(a.size());
    for (auto& v : o) v = prng.next_double();
    return StringCo(Kind::Ring, std::move(a), std::move(b), std::move(o), {}, {});
}

StringCo StringCo::plane(seeding::SeededPrng& prng, int dimensions) {
    std::vector<double> a, b;
    values(prng, dimensions, a, b);
    std::vector<double> o(a.size()), dx(a.size()), dy(a.size());
    for (std::size_t i = 0; i < a.size(); ++i) {
        const double theta = prng.next_double() * 2 * std::numbers::pi;
        dx[i] = std::cos(theta);
        dy[i] = std::sin(theta);
        const double min = net_min(0, dx[i]) + net_min(0, dy[i]);
        const double max = net_max(0, dx[i]) + net_max(0, dy[i]);
        const double span = prng.next_double() * (max - min);
        o[i] = min + span;
    }
    return StringCo(Kind::Plane, std::move(a), std::move(b), std::move(o), std::move(dx), std::move(dy));
}

Correlithm StringCo::at(double t) const {
    if (kind_ == Kind::Plane) throw std::logic_error("A planar string CO takes two coordinates.");
    if (std::isnan(t)) throw std::out_of_range("t must not be NaN.");
    std::vector<double> c(a_.size());
    if (kind_ == Kind::Line) {
        t = std::clamp(t, 0.0, 1.0);
        for (std::size_t i = 0; i < c.size(); ++i) c[i] = t < o_[i] ? a_[i] : b_[i];
    } else {
        // COR-T4 (docs/BUGS.md): infinity has no phase on a ring.
        if (std::isinf(t)) throw std::out_of_range("A ring has no position at infinity.");
        for (std::size_t i = 0; i < c.size(); ++i) {
            double phase = t - o_[i];
            phase -= std::floor(phase);
            c[i] = phase < 0.5 ? a_[i] : b_[i];
        }
    }
    return Correlithm(std::move(c));
}

Correlithm StringCo::at(double x, double y) const {
    if (kind_ != Kind::Plane) throw std::logic_error("Only a planar string CO takes two coordinates.");
    if (std::isnan(x) || std::isnan(y)) throw std::out_of_range("x and y must not be NaN.");
    x = std::clamp(x, 0.0, 1.0);
    y = std::clamp(y, 0.0, 1.0);
    std::vector<double> c(a_.size());
    for (std::size_t i = 0; i < c.size(); ++i) {
        const double px = x * dx_[i];
        const double py = y * dy_[i];
        const double p = px + py;
        c[i] = p < o_[i] ? a_[i] : b_[i];
    }
    return Correlithm(std::move(c));
}

Correlithm StringCo::at_index(int index, int count) const {
    if (count <= 0) throw std::out_of_range("count must be positive.");
    if (index < 0 || index >= count) throw std::out_of_range("index must lie in [0, count).");
    if (kind_ == Kind::Ring) return at(index / static_cast<double>(count));
    return at(count == 1 ? 0 : index / static_cast<double>(count - 1));
}

}  // namespace corobs::strings

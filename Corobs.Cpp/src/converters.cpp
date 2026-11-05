#include "corobs/converters.hpp"

namespace corobs::converters {
namespace {

strings::StringCo continuous_string(seeding::SeededPrng& prng, int dimensions, double min, double max, bool wraps) {
    if (!(max > min)) throw std::invalid_argument("max must exceed min.");
    return wraps ? strings::StringCo::ring(prng, dimensions) : strings::StringCo::line(prng, dimensions);
}

strings::StringCo planar_string(seeding::SeededPrng& prng, int dimensions, double min_x, double max_x, double min_y, double max_y) {
    if (!(max_x > min_x) || !(max_y > min_y)) throw std::invalid_argument("Each axis needs max > min.");
    return strings::StringCo::plane(prng, dimensions);
}

}  // namespace

ContinuousConverter::ContinuousConverter(seeding::SeededPrng& prng, int dimensions, double min, double max, bool wraps)
    : string_(continuous_string(prng, dimensions, min, max, wraps)),
      min_(min), max_(max), wraps_(wraps), dimensions_(dimensions),
      missing_(geometry::Correlithm::midpoint(dimensions)) {}

geometry::Correlithm ContinuousConverter::convert(const std::optional<double>& value) {
    if (!value || std::isnan(*value)) return missing_;
    // COR-T5 (docs/BUGS.md, a decision): a ring has no phase for infinity.
    if (wraps_ && std::isinf(*value)) return missing_;
    const double t = (*value - min_) / (max_ - min_);
    return string_.at(t);
}

PlanarConverter::PlanarConverter(seeding::SeededPrng& prng, int dimensions, double min_x, double max_x, double min_y, double max_y)
    : plane_(planar_string(prng, dimensions, min_x, max_x, min_y, max_y)),
      min_x_(min_x), max_x_(max_x), min_y_(min_y), max_y_(max_y), dimensions_(dimensions),
      missing_(geometry::Correlithm::midpoint(dimensions)) {}

geometry::Correlithm PlanarConverter::convert(const std::optional<std::pair<double, double>>& value) {
    if (!value) return missing_;
    const auto [x, y] = *value;
    if (std::isnan(x) || std::isnan(y)) return missing_;
    return plane_.at((x - min_x_) / (max_x_ - min_x_), (y - min_y_) / (max_y_ - min_y_));
}

}  // namespace corobs::converters

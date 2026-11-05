#pragma once

#include <cmath>
#include <functional>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "corobs/geometry.hpp"
#include "corobs/id_text.hpp"
#include "corobs/seeding.hpp"
#include "corobs/strings.hpp"

namespace corobs::converters {

/// Moves world data into CO space (a sensor, Ch. IX). A missing value lands on the cube's midpoint,
/// which carries no bits.
template <class T>
class Converter {
public:
    virtual ~Converter() = default;
    /// N: the dimensionality of the points this converter produces.
    virtual int dimensions() const noexcept = 0;
    /// The point for a value, or missing() for std::nullopt.
    virtual geometry::Correlithm convert(const std::optional<T>& value) = 0;
    /// Where an absent value lands: the midpoint.
    virtual const geometry::Correlithm& missing() const noexcept = 0;
};

/// A cardinal set (values with no order): each distinct value gets its own random CO, derived from
/// the seed and the value's key, so the mapping does not depend on arrival order.
template <class T>
class CardinalConverter final : public Converter<T> {
public:
    using Key = std::function<std::string(const T&)>;

    /// `key` defaults to id_text<T> (C#'s ToString()).
    CardinalConverter(const seeding::SeededPrng& root, int dimensions, Key key = {})
        : root_(root),
          key_(key ? std::move(key) : Key([](const T& v) { return id_text<T>::get(v); })),
          dimensions_(dimensions),
          missing_(geometry::Correlithm::midpoint(dimensions)) {}

    int dimensions() const noexcept override { return dimensions_; }
    const geometry::Correlithm& missing() const noexcept override { return missing_; }

    /// The value's CO (created and cached on first use), or missing() for std::nullopt.
    geometry::Correlithm convert(const std::optional<T>& value) override {
        if (!value) return missing_;
        auto k = key_(*value);
        auto it = cache_.find(k);
        if (it == cache_.end()) {
            auto child = root_.derive(k);
            it = cache_.emplace(std::move(k), geometry::Correlithm::random(child, dimensions_)).first;
        }
        return it->second;
    }

private:
    seeding::SeededPrng root_;
    Key key_;
    int dimensions_;
    geometry::Correlithm missing_;
    std::unordered_map<std::string, geometry::Correlithm> cache_;
};

/// An ordinal set (values with an order but no scale): evenly spaced positions on a line string
/// CO. An unknown value is an error (std::invalid_argument), not a guess.
template <class T, class Hash = std::hash<T>, class Eq = std::equal_to<T>>
class OrdinalConverter final : public Converter<T> {
public:
    OrdinalConverter(seeding::SeededPrng& prng, int dimensions, const std::vector<T>& order, Hash hash = {}, Eq eq = {})
        : index_(0, hash, eq),
          line_(make_line(prng, dimensions, order)),
          dimensions_(dimensions),
          missing_(geometry::Correlithm::midpoint(dimensions)) {
        for (std::size_t i = 0; i < order.size(); ++i)
            if (!index_.emplace(order[i], static_cast<int>(i)).second)
                throw std::invalid_argument("An ordinal set lists each value once.");
    }

    int dimensions() const noexcept override { return dimensions_; }
    const geometry::Correlithm& missing() const noexcept override { return missing_; }
    /// How many distinct values are in the order.
    int count() const noexcept { return static_cast<int>(index_.size()); }

    geometry::Correlithm convert(const std::optional<T>& value) override {
        if (!value) return missing_;
        auto it = index_.find(*value);
        if (it == index_.end()) throw std::invalid_argument("The value is not in this ordinal set.");
        return line_.at_index(it->second, count());
    }

private:
    static strings::StringCo make_line(seeding::SeededPrng& prng, int dimensions, const std::vector<T>& order) {
        if (order.empty()) throw std::invalid_argument("An ordinal set needs at least one value.");
        return strings::StringCo::line(prng, dimensions);
    }

    std::unordered_map<T, int, Hash, Eq> index_;
    strings::StringCo line_;
    int dimensions_;
    geometry::Correlithm missing_;
};

/// A continuous variable on [min, max] mapped onto a line string CO, or onto a ring when the range
/// wraps (hours, bearings). NaN, std::nullopt and, on a ring, +/-infinity give missing().
class ContinuousConverter final : public Converter<double> {
public:
    ContinuousConverter(seeding::SeededPrng& prng, int dimensions, double min, double max, bool wraps = false);

    int dimensions() const noexcept override { return dimensions_; }
    const geometry::Correlithm& missing() const noexcept override { return missing_; }
    geometry::Correlithm convert(const std::optional<double>& value) override;

private:
    strings::StringCo string_;
    double min_, max_;
    bool wraps_;
    int dimensions_;
    geometry::Correlithm missing_;
};

/// A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10). std::nullopt or
/// a NaN coordinate gives missing().
class PlanarConverter final : public Converter<std::pair<double, double>> {
public:
    PlanarConverter(seeding::SeededPrng& prng, int dimensions, double min_x, double max_x, double min_y, double max_y);

    int dimensions() const noexcept override { return dimensions_; }
    const geometry::Correlithm& missing() const noexcept override { return missing_; }
    geometry::Correlithm convert(const std::optional<std::pair<double, double>>& value) override;

private:
    strings::StringCo plane_;
    double min_x_, max_x_, min_y_, max_y_;
    int dimensions_;
    geometry::Correlithm missing_;
};

}  // namespace corobs::converters

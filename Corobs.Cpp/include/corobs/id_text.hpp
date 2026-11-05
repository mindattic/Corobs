#pragma once

#include <string>
#include <type_traits>

namespace corobs {

/// The text of an id or a key, as C#'s ToString() gives it: used for a cardinal converter's default
/// key and for the canonical order of a bench pair (ordinal comparison of this text). Specialize it
/// for your own id types.
template <class T, class = void>
struct id_text;

template <class T>
struct id_text<T, std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<T, bool>>> {
    static std::string get(const T& value) { return std::to_string(value); }
};

template <>
struct id_text<std::string> {
    static std::string get(const std::string& value) { return value; }
};

}  // namespace corobs

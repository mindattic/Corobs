"""
Converters (Ch. IX) move world data into CO space. Every converter answers the same question for a
missing value (`nothing` or `missing`): the cube's midpoint, which carries no bits.
"""
module Converters

using ..Seeding
using ..Geometry
using ..StringCOs
import ..Geometry: dimensions

export Converter, CardinalConverter, OrdinalConverter, ContinuousConverter, PlanarConverter,
    topoint, missingpoint, dimensions

"""
    Converter

A sensor (Ch. IX): `topoint(c, value)` gives a value's point, `missingpoint(c)` where an absent value
lands, `dimensions(c)` the N of the points it produces.
"""
abstract type Converter end

"Where an absent value lands: the midpoint of the converter's cube."
missingpoint(c::Converter) = c.missing
dimensions(c::Converter) = c.n

_absent(v) = v === nothing || v === missing

"""
    CardinalConverter(root::SeededPrng, n; key = string)

A cardinal set: values with no order (a faction, a species, a type). Each distinct value gets its own
random CO, derived from `root` and the value's key (`key(value)`, `string` by default) so the mapping
does not depend on the order values are first seen. Points are cached per key.
"""
struct CardinalConverter{F} <: Converter
    root::SeededPrng
    key::F
    n::Int
    missing::Correlithm
    cache::Dict{String,Correlithm}
end

CardinalConverter(root::SeededPrng, n::Integer; key = string) =
    CardinalConverter(root, key, Int(n), midpoint(n), Dict{String,Correlithm}())

function topoint(c::CardinalConverter, value)
    _absent(value) && return c.missing
    k = String(c.key(value))
    return get!(() -> random_correlithm(derive(c.root, k), c.n), c.cache, k)
end

"""
    OrdinalConverter(prng::SeededPrng, n, order; by = identity)

An ordinal set: values with an order but no scale (tiers, ranks, an alphabet), evenly spaced on a
fresh line string CO, so neighbours are near and the extremes are at standard distance (Fig. VII-8).
`by` maps a value to the key it is matched on. An unknown value is an error, not a guess.
"""
struct OrdinalConverter{F} <: Converter
    index::Dict{Any,Int}
    by::F
    line::StringCO
    n::Int
    missing::Correlithm
end

function OrdinalConverter(prng::SeededPrng, n::Integer, order::AbstractVector; by = identity)
    isempty(order) && throw(ArgumentError("An ordinal set needs at least one value."))
    index = Dict{Any,Int}()
    for (i, v) in enumerate(order)
        k = by(v)
        haskey(index, k) && throw(ArgumentError("'$v' appears twice in the ordinal set."))
        index[k] = i
    end
    line = line_co(prng, n)
    return OrdinalConverter(index, by, line, Int(n), midpoint(n))
end

"How many distinct values are in the order."
Base.length(c::OrdinalConverter) = length(c.index)

function topoint(c::OrdinalConverter, value)
    _absent(value) && return c.missing
    i = get(c.index, c.by(value), 0)
    i == 0 && throw(ArgumentError("'$value' is not in this ordinal set."))
    return at_index(c.line, i, length(c.index))
end

"""
    ContinuousConverter(prng::SeededPrng, n, min, max; wraps = false)

A continuous variable on [min, max] (an age, a date, a price) on a fresh line string CO, or on a
ring when `wraps` (hours of the day, compass bearings).
"""
struct ContinuousConverter <: Converter
    string::StringCO
    min::Float64
    max::Float64
    wraps::Bool
    n::Int
    missing::Correlithm
end

function ContinuousConverter(prng::SeededPrng, n::Integer, min::Real, max::Real; wraps::Bool = false)
    max > min || throw(ArgumentError("max must exceed min."))
    s = wraps ? ring_co(prng, n) : line_co(prng, n)
    return ContinuousConverter(s, Float64(min), Float64(max), wraps, Int(n), midpoint(n))
end

"""
The value's point on the string; `missingpoint` for `nothing`/`missing`, NaN, or an infinite value
on a ring, which has no phase to land on (COR-T5, docs/BUGS.md: a decision).
"""
function topoint(c::ContinuousConverter, value)
    _absent(value) && return c.missing
    v = Float64(value)
    isnan(v) && return c.missing
    c.wraps && isinf(v) && return c.missing
    t = (v - c.min) / (c.max - c.min)
    return at(c.string, t)
end

"""
    PlanarConverter(prng::SeededPrng, n, min_x, max_x, min_y, max_y)

A point in a bounded plane (a map position) on a fresh planar string CO (Fig. VII-10). Values are
`(x, y)` tuples.
"""
struct PlanarConverter <: Converter
    plane::StringCO
    min_x::Float64
    max_x::Float64
    min_y::Float64
    max_y::Float64
    n::Int
    missing::Correlithm
end

function PlanarConverter(prng::SeededPrng, n::Integer, min_x::Real, max_x::Real, min_y::Real, max_y::Real)
    (max_x > min_x && max_y > min_y) || throw(ArgumentError("Each axis needs max > min."))
    return PlanarConverter(plane_co(prng, n), Float64(min_x), Float64(max_x), Float64(min_y),
        Float64(max_y), Int(n), midpoint(n))
end

"The value's point on the plane; `missingpoint` for `nothing`/`missing` or a NaN coordinate."
function topoint(c::PlanarConverter, value)
    _absent(value) && return c.missing
    x = Float64(value[1]); y = Float64(value[2])
    (isnan(x) || isnan(y)) && return c.missing
    return at(c.plane, (x - c.min_x) / (c.max_x - c.min_x), (y - c.min_y) / (c.max_y - c.min_y))
end

end

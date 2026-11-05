"""
The real unit N-cube (Ch. II–III) and the points in it: [`Correlithm`](@ref) and the N-cube
statistics (`standard_distance`, `bit_content`, ...).
"""
module Geometry

using ..Seeding

export STANDARD_DEVIATION, RADIUS_DEVIATION, DIAMETER_DEVIATION,
    standard_distance, standard_radius, standard_diameter, corner_distance, half_diagonal,
    major_diagonal, deviations_below, distance_at_deviations, bit_content, distance_for_bits,
    probability_of_proximity, point_capacity
export Correlithm, random_correlithm, midpoint, dimensions, coordinates, squared_distance,
    distance, interpolate, centroid, superpose

# ---- N-cube statistics (Table II-1, Eq. III-H/J/Q). Valid for N of about 20 and up. ----

"σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N (Table II-1)."
const STANDARD_DEVIATION = 0.24152294576982397
"σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291."
const RADIUS_DEVIATION = 0.12909944487358055
"σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582."
const DIAMETER_DEVIATION = 0.2581988897471611

function _check(n::Integer)
    n > 0 || throw(DomainError(n, "A space needs at least one dimension; the statistics hold from about 20."))
    return n
end

"μ: expected distance between two random points, √(N/6)."
standard_distance(n::Integer) = sqrt(_check(n) / 6.0)
"Expected distance from the midpoint to a random point, √(N/12)."
standard_radius(n::Integer) = sqrt(_check(n) / 12.0)
"Expected distance from a corner to a random point, √(N/3)."
standard_diameter(n::Integer) = sqrt(_check(n) / 3.0)
"Expected distance between two random corners, √(N/2)."
corner_distance(n::Integer) = sqrt(_check(n) / 2.0)
"Midpoint to any corner, exactly √(N/4)."
half_diagonal(n::Integer) = sqrt(_check(n) / 4.0)
"Opposite corners, exactly √N."
major_diagonal(n::Integer) = sqrt(Float64(_check(n)))

"How many standard deviations below μ a distance lies (negative when beyond μ)."
deviations_below(n::Integer, d::Real) = (standard_distance(n) - d) / STANDARD_DEVIATION

"The distance that lies `k` σ below μ."
distance_at_deviations(n::Integer, k::Real) = standard_distance(n) - k * STANDARD_DEVIATION

"""
    bit_content(n, d)

Eq. III-H: bits of information in two points lying `d` apart, ((μ − d)/σ)² / ln 2 ≈ 24.75·(μ − d)².
Zero at or beyond standard distance.
"""
function bit_content(n::Integer, d::Real)
    x = deviations_below(n, d)
    return x <= 0 ? 0.0 : x * x / log(2.0)
end

"The distance at which proximity is worth `bits` bits."
function distance_for_bits(n::Integer, bits::Real)
    bits < 0 && throw(DomainError(bits, "bits must not be negative."))
    return standard_distance(n) - STANDARD_DEVIATION * sqrt(bits * log(2.0))
end

"Eq. III-J: the probability that two random points lie closer than `d`, 2^(−bits). One at or beyond μ."
probability_of_proximity(n::Integer, d::Real) = 2.0^(-bit_content(n, d))

"Eq. III-Q: how many random points fit before two are expected to lie closer than `d`, 10^(3.7(μ − d)²)."
function point_capacity(n::Integer, d::Real)
    gap = standard_distance(n) - d
    return gap <= 0 ? 1.0 : 10.0^(3.7 * gap * gap)
end

# ---- Correlithm objects ----

"""
    Correlithm(coordinates::AbstractVector{<:Real})

A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a *soft
token* (Ch. IV): it stands for its datum exactly at its coordinates and, to a degree
[`bit_content`](@ref) quantifies, at every point nearby. Immutable. Index it 1-based: `p[i]`.
"""
struct Correlithm
    c::Vector{Float64}

    function Correlithm(coords::AbstractVector{<:Real})
        isempty(coords) && throw(ArgumentError("A point needs at least one coordinate."))
        for v in coords
            (isnan(v) || v < 0 || v > 1) && throw(DomainError(v, "Every coordinate must lie in [0, 1]."))
        end
        return new(Float64[Float64(v) for v in coords])
    end
    Correlithm(c::Vector{Float64}, ::Val{:owned}) = new(c)
end

_owned(c::Vector{Float64}) = Correlithm(c, Val(:owned))

"N: the dimensionality of the cube a point (or string, or converter) lives in."
dimensions(p::Correlithm) = length(p.c)
"All N coordinates, in order (a copy)."
coordinates(p::Correlithm) = copy(p.c)
Base.getindex(p::Correlithm, i::Integer) = p.c[i]
Base.length(p::Correlithm) = length(p.c)

function _dims(n::Integer)
    n > 0 || throw(DomainError(n, "dimensions must be positive."))
    return Int(n)
end

"""
    random_correlithm(prng, n)

A point chosen uniformly at random from the whole cube: a fresh token, at standard distance from
every other random token with overwhelming probability.
"""
function random_correlithm(prng::SeededPrng, n::Integer)
    c = Vector{Float64}(undef, _dims(n))
    for i in eachindex(c)
        c[i] = next_double!(prng)
    end
    return _owned(c)
end

"The cube's centre, 0.5 in every dimension: where a missing value goes; it carries no bits."
midpoint(n::Integer) = _owned(fill(0.5, _dims(n)))

function _same(a::Correlithm, b::Correlithm)
    length(a.c) == length(b.c) || throw(ArgumentError("Points from different spaces have no distance."))
end

"Euclidean distance squared, summed in dimension order."
function squared_distance(a::Correlithm, b::Correlithm)
    _same(a, b)
    s = 0.0
    x = a.c; y = b.c
    for i in eachindex(x)
        d = x[i] - y[i]
        s += d * d
    end
    return s
end

"Euclidean distance; compare against [`standard_distance`](@ref) to read it as information."
distance(a::Correlithm, b::Correlithm) = sqrt(squared_distance(a, b))

"""
    interpolate(a, b, fraction)

Linear interpolation from `a` toward `b`. Ch. VII warns that interpolated points "take a shortcut"
and sit closer than standard distance to third points; use a string CO for sequences.
"""
function interpolate(a::Correlithm, b::Correlithm, fraction::Real)
    _same(a, b)
    (fraction < 0 || fraction > 1) && throw(DomainError(fraction, "fraction must lie in [0, 1]."))
    f = Float64(fraction)
    c = Vector{Float64}(undef, length(a.c))
    for i in eachindex(c)
        step = (b.c[i] - a.c[i]) * f
        c[i] = a.c[i] + step
    end
    return _owned(c)
end

"The coordinate-wise mean of a set of points, accumulated in order."
function centroid(points)
    isempty(points) && throw(ArgumentError("A centroid needs at least one point."))
    sum = nothing
    count = 0
    for p in points
        sum === nothing && (sum = zeros(length(p.c)))
        length(sum) == length(p.c) || throw(ArgumentError("All points must share one dimensionality."))
        for i in eachindex(sum)
            sum[i] += p.c[i]
        end
        count += 1
    end
    for i in eachindex(sum)
        sum[i] /= count
    end
    return _owned(sum)
end

"A point that superposes several: their centroid (Ch. VIII, Superposition)."
superpose(points) = centroid(points)

"True when every coordinate matches exactly; not a proximity test."
Base.:(==)(a::Correlithm, b::Correlithm) = a.c == b.c
Base.isequal(a::Correlithm, b::Correlithm) = a.c == b.c
# +0.0 folds -0.0 into 0.0 so equal points hash equal.
Base.hash(p::Correlithm, h::UInt) = hash([v + 0.0 for v in p.c], hash(:Correlithm, h))
Base.show(io::IO, p::Correlithm) = print(io, "CO[", length(p.c), "]")

end

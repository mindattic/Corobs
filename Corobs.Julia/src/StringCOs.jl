"""
String COs (Ch. VII): a line, a ring or a plane embedded in the N-cube so that distance along the
geometry is reflected as distance in the cube. Named `StringCOs` rather than `Strings` so it never
reads as text handling.
"""
module StringCOs

using ..Seeding
using ..Geometry
import ..Geometry: dimensions

export StringCO, line_co, ring_co, plane_co, at, at_index, dimensions

"""
    StringCO

A string CO (Ch. VII). Construction follows the book's advice to "distribute the anomalies
randomly": each dimension carries two random values and switches between them at its own random
breakpoint along the geometry, so two positions differ in exactly the dimensions whose breakpoint
lies between them: √|Δt|·μ on a line, √(2Δ)·μ around a ring (Δ ≤ ½), isotropic in the plane. No
interpolation is involved, so no position "takes a shortcut" toward third points. Build one with
[`line_co`](@ref), [`ring_co`](@ref) or [`plane_co`](@ref).
"""
struct StringCO
    kind::Symbol
    a::Vector{Float64}
    b::Vector{Float64}
    o::Vector{Float64}
    dx::Union{Nothing,Vector{Float64}}
    dy::Union{Nothing,Vector{Float64}}
end

dimensions(s::StringCO) = length(s.a)
Base.show(io::IO, s::StringCO) = print(io, "StringCO(:", s.kind, ", ", length(s.a), ")")

function _values(prng::SeededPrng, n::Integer)
    n > 0 || throw(DomainError(n, "dimensions must be positive."))
    a = Vector{Float64}(undef, n)
    b = Vector{Float64}(undef, n)
    for i in 1:n
        a[i] = next_double!(prng)
        b[i] = next_double!(prng)
    end
    return a, b
end

"A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|."
function line_co(prng::SeededPrng, n::Integer)
    a, b = _values(prng, n)
    o = [next_double!(prng) for _ in 1:n]
    return StringCO(:line, a, b, o, nothing, nothing)
end

"A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1, for hours, headings, seasons."
function ring_co(prng::SeededPrng, n::Integer)
    a, b = _values(prng, n)
    o = [next_double!(prng) for _ in 1:n]
    return StringCO(:ring, a, b, o, nothing, nothing)
end

# .NET Math.Min/Max order signed zeros (min(0, -0) is -0); Julia's min/max do the same.
"""
A unit square parameterised by (x, y) ∈ [0, 1]². Each dimension watches a random direction, so
distance grows with planar separation alike in every direction (the cone of Fig. VII-10).
"""
function plane_co(prng::SeededPrng, n::Integer)
    a, b = _values(prng, n)
    o = Vector{Float64}(undef, n)
    dx = Vector{Float64}(undef, n)
    dy = Vector{Float64}(undef, n)
    for i in 1:n
        theta = (next_double!(prng) * 2.0) * 3.141592653589793
        dx[i] = cos(theta)
        dy[i] = sin(theta)
        lo = min(0.0, dx[i]) + min(0.0, dy[i])
        hi = max(0.0, dx[i]) + max(0.0, dy[i])
        span = next_double!(prng) * (hi - lo)
        o[i] = lo + span
    end
    return StringCO(:plane, a, b, o, dx, dy)
end

"""
    at(s, t)

The point at position `t` on a line (clamped to [0, 1]) or a ring (taken mod 1). A ring has no
position at ±∞ (COR-T4, docs/BUGS.md).
"""
function at(s::StringCO, t::Real)
    s.kind === :plane && throw(ArgumentError("A planar string CO takes two coordinates."))
    t = Float64(t)
    isnan(t) && throw(DomainError(t, "t must not be NaN."))
    n = length(s.a)
    c = Vector{Float64}(undef, n)
    if s.kind === :line
        t = clamp(t, 0.0, 1.0)
        for i in 1:n
            c[i] = t < s.o[i] ? s.a[i] : s.b[i]
        end
    else
        isinf(t) && throw(DomainError(t, "A ring has no position at infinity."))
        for i in 1:n
            phase = t - s.o[i]
            phase -= floor(phase)
            c[i] = phase < 0.5 ? s.a[i] : s.b[i]
        end
    end
    return Geometry._owned(c)
end

"The point at (x, y) on a plane, each clamped to [0, 1]."
function at(s::StringCO, x::Real, y::Real)
    s.kind === :plane || throw(ArgumentError("Only a planar string CO takes two coordinates."))
    x = Float64(x); y = Float64(y)
    (isnan(x) || isnan(y)) && throw(DomainError((x, y), "x and y must not be NaN."))
    x = clamp(x, 0.0, 1.0)
    y = clamp(y, 0.0, 1.0)
    n = length(s.a)
    c = Vector{Float64}(undef, n)
    for i in 1:n
        px = x * s.dx[i]
        py = y * s.dy[i]
        p = px + py
        c[i] = p < s.o[i] ? s.a[i] : s.b[i]
    end
    return Geometry._owned(c)
end

"""
    at_index(s, i, count)

The `i`-th (1-based) of `count` evenly spaced positions: an ordinal set such as an alphabet, a rank
or a tier (Fig. VII-8). On a ring the positions are (i−1)/count; on a line (i−1)/(count−1).
"""
function at_index(s::StringCO, i::Integer, count::Integer)
    count <= 0 && throw(DomainError(count, "count must be positive."))
    (i < 1 || i > count) && throw(DomainError(i, "index must lie in 1:count."))
    s.kind === :ring && return at(s, (i - 1) / count)
    return at(s, count == 1 ? 0.0 : (i - 1) / (count - 1))
end

end

"""
Deterministic randomness: everything stochastic in COROBS draws from a [`SeededPrng`](@ref), so a
space can be rebuilt bit for bit from its seed.
"""
module Seeding

export SeededPrng, next_uint64!, next_double!, next_int!, derive

"""
    SeededPrng(seed::Integer)

A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed yields
the same values on every machine and every Julia version, unlike `Random`, whose algorithms are not
a contract. `p.seed` is the signed 64-bit root seed the stream was built from.
"""
mutable struct SeededPrng
    const seed::Int64
    s0::UInt64
    s1::UInt64
    s2::UInt64
    s3::UInt64

    function SeededPrng(seed::Integer)
        s = Int64(seed)
        x = reinterpret(UInt64, s)
        x, a = _splitmix(x)
        x, b = _splitmix(x)
        x, c = _splitmix(x)
        x, d = _splitmix(x)
        new(s, a, b, c, d)
    end
end

Base.show(io::IO, p::SeededPrng) = print(io, "SeededPrng(", p.seed, ")")

function _splitmix(x::UInt64)
    x += 0x9e3779b97f4a7c15
    z = x
    z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
    return x, z ⊻ (z >> 31)
end

"""
    next_uint64!(p::SeededPrng) -> UInt64

The next raw 64-bit word of the xoshiro256** stream; [`next_double!`](@ref) and
[`next_int!`](@ref) are built on it.
"""
function next_uint64!(p::SeededPrng)
    result = bitrotate(p.s1 * 0x0000000000000005, 7) * 0x0000000000000009
    t = p.s1 << 17
    p.s2 ⊻= p.s0
    p.s3 ⊻= p.s1
    p.s1 ⊻= p.s2
    p.s0 ⊻= p.s3
    p.s2 ⊻= t
    p.s3 = bitrotate(p.s3, 45)
    return result
end

"""
    next_double!(p::SeededPrng) -> Float64

Uniform on [0, 1): the top 53 bits of the next word, times 2⁻⁵³.
"""
next_double!(p::SeededPrng) = Float64(next_uint64!(p) >> 11) * (1.0 / 9007199254740992.0)

"""
    next_int!(p::SeededPrng, max_exclusive::Integer) -> Int

Uniform integer on [0, `max_exclusive`): `trunc(next_double! × max_exclusive)`.
"""
function next_int!(p::SeededPrng, max_exclusive::Integer)
    max_exclusive <= 0 && throw(DomainError(max_exclusive, "max_exclusive must be positive."))
    return trunc(Int, next_double!(p) * max_exclusive)
end

"""
    derive(p::SeededPrng, label::AbstractString) -> SeededPrng

A child stream named by `label`: the same parent seed and label always give the same child,
independent of how many values the parent has produced. This is how a converter gets one fixed
point per category value (`PRNG(seed, ply, value)`). FNV-1a over the seed's 8 little-endian bytes,
then the label's UTF-8 bytes.
"""
derive(p::SeededPrng, label::AbstractString) = SeededPrng(reinterpret(Int64, _fnv1a64(p.seed, String(label))))

function _fnv1a64(seed::Int64, label::String)
    h = 0xcbf29ce484222325
    prime = 0x00000100000001b3
    s = reinterpret(UInt64, seed)
    for i in 0:7
        h ⊻= (s >> (8 * i)) & 0x00000000000000ff
        h *= prime
    end
    for b in codeunits(label)
        h ⊻= UInt64(b)
        h *= prime
    end
    return h
end

end

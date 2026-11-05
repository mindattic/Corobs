"""
Pattern and rule mining (Ch. IV, X–XI): clusters far tighter than chance, rules `s.p >: t.q` between
them, and cues: ranked contradiction candidates for a human to resolve. Measurement, never judgment.
"""
module Mining

using ..Geometry

export PlyPoint, Pattern, PatternMiner, Rule, RuleMiner, Hit, Cue, mine, find_hits

"One thing's position on one ply (subspace)."
struct PlyPoint{TId}
    id::TId
    point::Correlithm
end

"""
    Pattern

An emergent truth: things whose points on one ply lie far closer together than chance allows.
Proposed by [`PatternMiner`](@ref); what it means, and whether it is true, is the caller's decision.
`id in pattern` tests membership under the miner's `key`.
"""
struct Pattern{TId,F}
    members::Vector{TId}
    centroid::Correlithm
    radius::Float64
    mean_pair_distance::Float64
    bits::Float64
    key::F
    set::Set{Any}
end

Pattern(members::Vector{TId}, centroid::Correlithm, radius::Real, mean_pair_distance::Real, bits::Real;
    key = identity) where {TId} =
    Pattern(members, centroid, Float64(radius), Float64(mean_pair_distance), Float64(bits), key,
        Set{Any}(key(m) for m in members))

Base.in(id, p::Pattern) = p.key(id) in p.set
Base.show(io::IO, p::Pattern) = print(io, "Pattern[", length(p.members), " members, ", round(p.bits; digits = 1), " bits]")

"""
    PatternMiner(; min_deviations = 6, min_members = 5)

Links two points when they lie at least `min_deviations` σ below standard distance (≈ 52 bits at 6σ,
Eq. III-H), joins linked points by union-find, and keeps components of at least `min_members`.
"""
struct PatternMiner
    min_deviations::Float64
    min_members::Int
    function PatternMiner(; min_deviations::Real = 6, min_members::Integer = 5)
        min_deviations <= 0 && throw(DomainError(min_deviations, "min_deviations must be positive."))
        min_members < 2 && throw(DomainError(min_members, "min_members must be at least 2."))
        new(Float64(min_deviations), Int(min_members))
    end
end

"""
    mine(miner::PatternMiner, points; lt = isless, key = identity) -> Vector{Pattern}

The patterns among `points` (all on one ply), ordered by bits descending then by first member under
`lt`. Points are processed in id order (`lt`); `key` is the equality key each pattern tests
membership with. Deterministic.
"""
function mine(miner::PatternMiner, points::AbstractVector{PlyPoint{TId}}; lt = isless, key = identity) where {TId}
    length(points) < miner.min_members && return Pattern{TId,typeof(key)}[]
    n = dimensions(points[1].point)
    sorted = sort(collect(points); by = p -> p.id, lt = lt, alg = MergeSort)
    threshold = distance_at_deviations(n, miner.min_deviations)
    # COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
    threshold < 0 && return Pattern{TId,typeof(key)}[]
    threshold_sq = threshold * threshold

    m = length(sorted)
    parent = collect(1:m)
    for i in 1:m
        p_i = sorted[i].point
        for j in i+1:m
            squared_distance(p_i, sorted[j].point) <= threshold_sq && _union!(parent, i, j)
        end
    end

    roots = Int[]
    groups = Dict{Int,Vector{Int}}()
    for i in 1:m
        r = _find!(parent, i)
        if !haskey(groups, r)
            groups[r] = Int[]
            push!(roots, r)
        end
        push!(groups[r], i)
    end

    result = Pattern{TId,typeof(key)}[]
    for r in roots
        idx = groups[r]
        length(idx) < miner.min_members && continue
        pts = [sorted[i].point for i in idx]
        c = centroid(pts)
        radius = maximum(distance(p, c) for p in pts)
        total = 0.0
        pairs = 0
        for a in 1:length(pts), b in a+1:length(pts)
            total += distance(pts[a], pts[b])
            pairs += 1
        end
        mean = total / pairs
        push!(result, Pattern(TId[sorted[i].id for i in idx], c, radius, mean, bit_content(n, mean); key = key))
    end
    return sort(result; lt = (p, q) -> p.bits > q.bits || (p.bits == q.bits && lt(p.members[1], q.members[1])),
        alg = MergeSort)
end

function _find!(parent::Vector{Int}, i::Int)
    while parent[i] != i
        parent[i] = parent[parent[i]]
        i = parent[i]
    end
    return i
end

function _union!(parent::Vector{Int}, a::Int, b::Int)
    ra = _find!(parent, a); rb = _find!(parent, b)
    ra == rb && return
    if ra < rb
        parent[rb] = ra
    else
        parent[ra] = rb
    end
end

"""
    Rule

A rule `s.p >: t.q` (Ch. IV): things inside pattern `source` on ply `source_ply` are found inside
pattern `target` on ply `target_ply` with the given `support`. `bits` = support × the source's bits.
"""
struct Rule{P<:Pattern}
    source_ply::String
    source::P
    target_ply::String
    target::P
    support::Float64
    bits::Float64
end

Base.show(io::IO, r::Rule) = print(io, r.source_ply, ".[", length(r.source.members), "] >: ", r.target_ply,
    ".[", length(r.target.members), "] support ", round(Int, 100 * r.support), "%, ", round(r.bits; digits = 1), " bits")

"""
    RuleMiner(; min_support = 0.8)

Proposes rules between the patterns of two plies: for every source pattern, the target pattern that
holds the largest share of its members, kept when that share reaches `min_support`.
"""
struct RuleMiner
    min_support::Float64
    function RuleMiner(; min_support::Real = 0.8)
        (min_support <= 0 || min_support > 1) && throw(DomainError(min_support, "min_support must lie in (0, 1]."))
        new(Float64(min_support))
    end
end

"""
    mine(miner::RuleMiner, source_ply, source, target_ply, target) -> Vector{Rule}

The rules from `source_ply`'s patterns to `target_ply`'s that reach `min_support`, ordered by bits
descending (ties keep source order).
"""
function mine(miner::RuleMiner, source_ply::AbstractString, source::AbstractVector{P},
    target_ply::AbstractString, target::AbstractVector{P}) where {P<:Pattern}
    source_ply == target_ply && throw(ArgumentError("A rule relates two different plies."))
    rules = Rule{P}[]
    for p in source
        best = nothing
        best_count = 0
        for q in target
            k = count(m -> m in q, p.members)
            if k > best_count
                best = q
                best_count = k
            end
        end
        best === nothing && continue
        support = best_count / length(p.members)
        support >= miner.min_support &&
            push!(rules, Rule{P}(String(source_ply), p, String(target_ply), best, support, support * p.bits))
    end
    return sort(rules; lt = (a, b) -> a.bits > b.bits, alg = MergeSort)
end

"""
    Hit

A ranked contradiction candidate: a thing inside a rule's source pattern that lies at or near
standard distance from the rule's target, the anomaly a cueing system hands to the expert (Ch. X–XI).
"""
struct Hit{TId,R<:Rule}
    id::TId
    rule::R
    source_distance::Float64
    target_distance::Float64
    bits::Float64
    rank::Int
end

Base.show(io::IO, h::Hit) = print(io, "#", h.rank, " ", h.id, ": ", round(h.bits; digits = 1), " bits — ", h.rule)

"""
    Cue(; target_deviations = 1)

A member of a rule's source whose target-ply point lies no closer than `target_deviations` σ below
standard distance from the target centroid is a hit. Bits = (bits of the member's own distance to
the source centroid) × support.
"""
struct Cue
    target_deviations::Float64
    function Cue(; target_deviations::Real = 1)
        target_deviations < 0 && throw(DomainError(target_deviations, "target_deviations must not be negative."))
        new(Float64(target_deviations))
    end
end

"""
    find_hits(cue, rules, plies; lt = isless) -> Vector{Hit}

`plies` maps each ply name to a dictionary of points by id. Hits are ordered by bits descending then
id under `lt`, ranked from 1.
"""
function find_hits(cue::Cue, rules::AbstractVector{<:Rule}, plies::AbstractDict; lt = isless)
    raw = Hit[]
    for rule in rules
        haskey(plies, rule.source_ply) || throw(ArgumentError("No points for ply '$(rule.source_ply)'."))
        haskey(plies, rule.target_ply) || throw(ArgumentError("No points for ply '$(rule.target_ply)'."))
        source_points = plies[rule.source_ply]
        target_points = plies[rule.target_ply]
        n = dimensions(rule.target.centroid)
        far_enough = distance_at_deviations(n, cue.target_deviations)
        for id in rule.source.members
            tp = get(target_points, id, nothing)
            sp = get(source_points, id, nothing)
            (tp === nothing || sp === nothing) && continue
            td = distance(tp, rule.target.centroid)
            td < far_enough && continue
            sd = distance(sp, rule.source.centroid)
            push!(raw, Hit(id, rule, sd, td, bit_content(dimensions(sp), sd) * rule.support, 0))
        end
    end
    sorted = sort(raw; lt = (a, b) -> a.bits > b.bits || (a.bits == b.bits && lt(a.id, b.id)), alg = MergeSort)
    return Hit[Hit(h.id, h.rule, h.source_distance, h.target_distance, h.bits, i) for (i, h) in enumerate(sorted)]
end

end

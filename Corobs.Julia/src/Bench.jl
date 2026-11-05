"""
Scores any way of relating things against any other on the same ground truth. Everything here is
arithmetic over ids; the caller supplies the truth and the predictors.
"""
module Bench

using ..Seeding

export RecallResult, ReachResult, holdout_recall, reach, cascade_yield

"""
    RecallResult

How well a neighbour function recovers relationships hidden from it. `r.recall` is the share of
hidden pairs recovered; `r.precision` the share of the predictor's guesses that are true anywhere in
the full truth.
"""
struct RecallResult
    hidden::Int
    recovered::Int
    predicted::Int
    predicted_true::Int
end

function Base.getproperty(r::RecallResult, s::Symbol)
    s === :recall && return getfield(r, :hidden) == 0 ? 0.0 : getfield(r, :recovered) / getfield(r, :hidden)
    s === :precision && return getfield(r, :predicted) == 0 ? 0.0 : getfield(r, :predicted_true) / getfield(r, :predicted)
    return getfield(r, s)
end
Base.propertynames(::RecallResult, private::Bool = false) = (:hidden, :recovered, :predicted, :predicted_true, :recall, :precision)

"How far a thing can reach: mean reachable count per hop, and how many reach nothing (dead records)."
struct ReachResult
    mean_reachable_by_hop::Vector{Float64}
    isolated::Int
    total::Int
end

# C# string.CompareOrdinal on the ids' text: UTF-16 code-unit order.
_canon(a, b) = cmp(transcode(UInt16, string(a)), transcode(UInt16, string(b))) <= 0 ? (a, b) : (b, a)

"""
    holdout_recall(true_pairs, holdout_fraction, seed, neighbours; key = identity) -> RecallResult

Hide `holdout_fraction` of the true relationships (deterministically, by seed), ask `neighbours(id)`
for each hidden endpoint's neighbours, and count how many hidden relationships come back. A
relationship is an unordered pair under `key`; listing it twice, or both ways round, is still one
(COR-T4, docs/BUGS.md). The hidden count is the round-half-to-even of count × fraction.
"""
function holdout_recall(true_pairs, holdout_fraction::Real, seed::Integer, neighbours; key = identity)
    (holdout_fraction <= 0 || holdout_fraction >= 1) &&
        throw(DomainError(holdout_fraction, "holdout_fraction must lie in (0, 1)."))
    pk(p) = Set{Any}((key(p[1]), key(p[2])))
    truth = Set{Any}(pk(p) for p in true_pairs)

    prng = SeededPrng(seed)
    shuffled = Tuple[]
    seen_distinct = Set{Any}()
    for p in true_pairs
        c = _canon(p[1], p[2])
        k = pk(c)
        k in seen_distinct && continue
        push!(seen_distinct, k)
        push!(shuffled, c)
    end
    for i in length(shuffled):-1:2
        j = next_int!(prng, i) + 1
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    count = round(Int, length(shuffled) * Float64(holdout_fraction))
    hidden = [_canon(p[1], p[2]) for p in shuffled[1:count]]
    hidden_set = Set{Any}(pk(p) for p in hidden)

    endpoints = Any[]
    endpoint_keys = Set{Any}()
    for p in hidden, e in (p[1], p[2])
        k = key(e)
        k in endpoint_keys && continue
        push!(endpoint_keys, k)
        push!(endpoints, e)
    end

    recovered = 0; predicted = 0; predicted_true = 0
    seen = Set{Any}()
    for e in endpoints, nb in neighbours(e)
        k = pk(_canon(e, nb))
        k in seen && continue
        push!(seen, k)
        predicted += 1
        k in truth && (predicted_true += 1)
        if k in hidden_set
            delete!(hidden_set, k)
            recovered += 1
        end
    end
    return RecallResult(length(hidden), recovered, predicted, predicted_true)
end

"""
    reach(ids, adjacency, max_hops; key = identity) -> ReachResult

Breadth-first reach from every id through `adjacency(id)`, up to `max_hops`.
"""
function reach(ids, adjacency, max_hops::Integer; key = identity)
    max_hops <= 0 && throw(DomainError(max_hops, "max_hops must be positive."))
    all_ids = collect(ids)
    sums = zeros(max_hops)
    isolated = 0
    for start in all_ids
        visited = Set{Any}((key(start),))
        frontier = Any[start]
        reached = 0
        for hop in 1:max_hops
            next = Any[]
            for f in frontier, a in adjacency(f)
                k = key(a)
                k in visited && continue
                push!(visited, k)
                push!(next, a)
            end
            reached += length(next)
            sums[hop] += reached
            frontier = next
            if isempty(next)
                for h in hop+1:max_hops
                    sums[h] += reached
                end
                break
            end
        end
        reached == 0 && (isolated += 1)
    end
    means = [isempty(all_ids) ? 0.0 : s / length(all_ids) for s in sums]
    return ReachResult(means, isolated, length(all_ids))
end

"Hits that closed because something else was fixed, per direct fix. The old way scores zero by construction."
cascade_yield(closed_by_cascade::Integer, direct_fixes::Integer) =
    direct_fixes == 0 ? 0.0 : closed_by_cascade / direct_fixes

end

# COR-T4 and COR-T5 (docs/BUGS.md). Each test asserts an invariant, not an implementation; the C#
# reference keeps the old code behind its symbol, and these ports carry only the fixed behaviour.

function _oracle(pairs, key)
    map = Dict{Any,Vector{Any}}()
    for (a, b) in pairs
        push!(get!(map, key(a), Any[]), b)
        push!(get!(map, key(b), Any[]), a)
    end
    return id -> get(map, key(id), Any[])
end

@testset "Bugs" begin
    @testset "COR-T4 threshold: no pattern member is linked by a pair short of the required σ" begin
        n = 4
        miner = PatternMiner(min_deviations = 6, min_members = 5)
        @test distance_at_deviations(n, miner.min_deviations) < 0   # precondition: μ − 6σ < 0 at N = 4
        points = [PlyPoint(k, Correlithm([0.1 * k, 0.5, 0.5, 0.5])) for k in 0:4]
        for pattern in mine(miner, points), id in pattern.members
            p = points[id+1].point
            best = maximum(deviations_below(n, distance(p, points[o+1].point)) for o in pattern.members if o != id)
            @test best >= miner.min_deviations
        end
    end

    @testset "COR-T4 ring: at never returns a point off the ring (t = $t)" for t in (Inf, -Inf)
        n = 32
        ring = ring_co(SeededPrng(42), n)
        p = try
            at(ring, t)
        catch e
            e isa DomainError || rethrow()
            nothing
        end
        if p !== nothing
            # A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
            steps = 200_000
            on_ring = Set(at(ring, k / steps) for k in 0:steps-1)
            @test length(on_ring) == 2n        # precondition: the grid visits every ring point
            @test p in on_ring                 # Ch. IX, p. 123: exactly on the string
        else
            @test p === nothing
        end
    end

    @testset "COR-T4 pairs: a perfect predictor recovers every hidden relationship even when listed repeatedly" begin
        pairs = Tuple{Int,Int}[]
        for i in 0:19
            push!(pairs, (2i, 2i + 1)); push!(pairs, (2i, 2i + 1)); push!(pairs, (2i + 1, 2i))
        end
        r = holdout_recall(pairs, 0.5, 7, _oracle(pairs, identity))
        @test r.recall == 1.0
    end

    @testset "COR-T4 pairs: one relationship under the caller's key is hidden once" begin
        pairs = Tuple{String,String}[]
        for i in 0:19
            push!(pairs, ("a$i", "B$i")); push!(pairs, ("b$i", "A$i"))
        end
        r = holdout_recall(pairs, 0.5, 7, _oracle(pairs, lowercase); key = lowercase)
        @test r.hidden == 10   # 20 relationships, half hidden; each spelled two ways is still one
    end

    @testset "COR-T5 decision: a wrapping converter maps infinity to missing (value = $v)" for v in (Inf, -Inf)
        hours = ContinuousConverter(SeededPrng(1), 32, 0, 24; wraps = true)
        @test topoint(hours, v) == missingpoint(hours)
    end
end

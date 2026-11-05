const MINING_N = 64

function _near(centre::Correlithm, prng::SeededPrng, jitter::Float64)
    c = Vector{Float64}(undef, dimensions(centre))
    for i in eachindex(c)
        offset = ((next_double!(prng) - 0.5) * 2) * jitter
        c[i] = clamp(centre[i] + offset, 0.0, 1.0)
    end
    return Correlithm(c)
end

@testset "Mining" begin
    @testset "a planted cluster among random points is the only pattern" begin
        prng = SeededPrng(100)
        points = PlyPoint{Int}[]
        for i in 0:999
            push!(points, PlyPoint(i, random_correlithm(prng, MINING_N)))
        end
        centre = random_correlithm(prng, MINING_N)
        for i in 1000:1005
            push!(points, PlyPoint(i, _near(centre, prng, 0.05)))
        end
        patterns = mine(PatternMiner(min_deviations = 6, min_members = 5), points)
        @test length(patterns) == 1
        @test sort(patterns[1].members) == collect(1000:1005)
        @test patterns[1].bits > bit_content(MINING_N, distance_at_deviations(MINING_N, 6))
        @test patterns[1].radius < patterns[1].mean_pair_distance
    end

    @testset "random points alone yield no pattern" begin
        prng = SeededPrng(101)
        points = [PlyPoint(i, random_correlithm(prng, MINING_N)) for i in 0:1499]
        @test isempty(mine(PatternMiner(), points))
    end

    @testset "mining is deterministic" begin
        function make()
            p = SeededPrng(102)
            [PlyPoint(i, i < 8 ? _near(midpoint(MINING_N), p, 0.05) : random_correlithm(p, MINING_N)) for i in 0:299]
        end
        a = mine(PatternMiner(), make()); b = mine(PatternMiner(), make())
        @test [p.members for p in a] == [p.members for p in b]
        @test [p.bits for p in a] == [p.bits for p in b]
    end

    @testset "a rule emerges and the one member that breaks it is the top hit" begin
        prng = SeededPrng(103)
        cs = random_correlithm(prng, MINING_N)   # where the faction sits on ply s
        ct = random_correlithm(prng, MINING_N)   # where its turf sits on ply t
        s = PlyPoint{Int}[]; t = PlyPoint{Int}[]
        for id in 1:10; push!(s, PlyPoint(id, _near(cs, prng, 0.05))); end    # ten members of one faction
        for id in 1:9;  push!(t, PlyPoint(id, _near(ct, prng, 0.05))); end    # nine share the turf
        push!(t, PlyPoint(10, random_correlithm(prng, MINING_N)))             # one lives somewhere unrelated
        for id in 11:40
            push!(s, PlyPoint(id, random_correlithm(prng, MINING_N)))
            push!(t, PlyPoint(id, random_correlithm(prng, MINING_N)))
        end

        miner = PatternMiner()
        ps = mine(miner, s); pt = mine(miner, t)
        @test length(ps) == 1
        @test length(pt) == 1

        rules = mine(RuleMiner(min_support = 0.8), "faction", ps, "turf", pt)
        @test length(rules) == 1
        @test isapprox(rules[1].support, 0.9; atol = 1e-9)

        plies = Dict("faction" => Dict(p.id => p.point for p in s), "turf" => Dict(p.id => p.point for p in t))
        hits = find_hits(Cue(), rules, plies)
        @test length(hits) == 1
        @test hits[1].id == 10
        @test hits[1].rank == 1
        @test hits[1].bits > 0
        @test hits[1].target_distance > distance_at_deviations(MINING_N, 1)
    end

    @testset "a rule needs support" begin
        prng = SeededPrng(104)
        cs = random_correlithm(prng, MINING_N); ct = random_correlithm(prng, MINING_N)
        s = [PlyPoint(id, _near(cs, prng, 0.05)) for id in 1:10]
        t = vcat([PlyPoint(id, _near(ct, prng, 0.05)) for id in 1:5],
                 [PlyPoint(id, random_correlithm(prng, MINING_N)) for id in 6:10])
        miner = PatternMiner()
        @test isempty(mine(RuleMiner(min_support = 0.8), "a", mine(miner, s), "b", mine(miner, t)))   # half is not a rule
        @test_throws ArgumentError mine(RuleMiner(), "a", mine(miner, s), "a", mine(miner, t))
    end

    @testset "invalid arguments" begin
        @test_throws DomainError PatternMiner(min_deviations = 0)
        @test_throws DomainError PatternMiner(min_members = 1)
        @test_throws DomainError RuleMiner(min_support = 0)
        @test_throws DomainError RuleMiner(min_support = 1.5)
        @test_throws DomainError Cue(target_deviations = -1)
    end
end

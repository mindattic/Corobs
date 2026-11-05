@testset "Bench" begin
    @testset "holdout recall counts hidden pairs the predictor recovers" begin
        pairs = [("a$i", "b$i") for i in 0:19]
        all = Dict{String,Vector{String}}()
        for (a, b) in pairs
            push!(get!(all, a, String[]), b)
            push!(get!(all, b, String[]), a)
        end
        # A predictor that knows every pair recovers everything with perfect precision.
        perfect = holdout_recall(pairs, 0.25, 1, id -> get(all, id, String[]))
        @test perfect.hidden == 5
        @test perfect.recall == 1
        @test perfect.precision == 1
        # A predictor that knows nothing recovers nothing.
        blind = holdout_recall(pairs, 0.25, 1, _ -> String[])
        @test blind.recall == 0
        # Same seed, same hidden set.
        @test holdout_recall(pairs, 0.25, 1, _ -> String[]).hidden == blind.hidden
        @test_throws DomainError holdout_recall(pairs, 1.0, 1, _ -> String[])
    end

    @testset "reach counts hops and isolated records" begin
        adj = Dict(1 => [2], 2 => [1, 3], 3 => [2], 4 => Int[])
        r = reach([1, 2, 3, 4], id -> adj[id], 2)
        @test r.isolated == 1
        @test r.total == 4
        @test r.mean_reachable_by_hop[1] == (1 + 2 + 1 + 0) / 4.0
        @test r.mean_reachable_by_hop[2] == (2 + 2 + 2 + 0) / 4.0
        @test_throws DomainError reach([1], id -> adj[id], 0)
    end

    @testset "cascade yield is closed by cascade per direct fix" begin
        @test cascade_yield(6, 4) == 1.5
        @test cascade_yield(0, 0) == 0
    end
end

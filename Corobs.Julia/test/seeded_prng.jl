@testset "SeededPrng" begin
    @testset "same seed, same stream" begin
        a = SeededPrng(42); b = SeededPrng(42)
        @test all(next_uint64!(a) == next_uint64!(b) for _ in 1:1000)
    end

    @testset "different seeds differ" begin
        a = SeededPrng(1); b = SeededPrng(2)
        @test [next_uint64!(a) for _ in 1:16] != [next_uint64!(b) for _ in 1:16]
    end

    @testset "doubles are uniform on the unit interval" begin
        p = SeededPrng(99)
        xs = [next_double!(p) for _ in 1:20000]
        @test all(0.0 .<= xs .< 1.0)
        @test isapprox(sum(xs) / length(xs), 0.5; atol = 0.01)
    end

    @testset "derive is deterministic and independent of consumption" begin
        a = SeededPrng(5)
        next_uint64!(a); next_uint64!(a)
        b = SeededPrng(5)
        @test derive(a, "faction").seed == derive(b, "faction").seed
        @test derive(a, "faction").seed != derive(b, "turf").seed
        @test derive(a, "faction").seed != a.seed
    end

    @testset "next_int! needs a positive bound" begin
        @test_throws DomainError next_int!(SeededPrng(1), 0)
        p = SeededPrng(3)
        @test all(0 <= next_int!(p, 7) < 7 for _ in 1:1000)
    end
end

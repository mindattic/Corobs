# Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ.
const STRING_N = 2048 # large so a single string's statistics are tight

@testset "StringCO" begin
    @testset "line distance grows as the root of separation and reaches μ" begin
        line = line_co(SeededPrng(11), STRING_N)
        mu = standard_distance(STRING_N)
        origin = at(line, 0)
        d1 = distance(origin, at(line, 0.1))
        d3 = distance(origin, at(line, 0.3))
        d6 = distance(origin, at(line, 0.6))
        d10 = distance(origin, at(line, 1.0))
        @test d1 < d3 < d6 < d10
        @test isapprox(d1 / mu, sqrt(0.1); atol = 0.06)     # ≈ μ·√|Δt|
        @test isapprox(d10 / mu, 1; atol = 0.06)            # the far ends are at standard distance
        @test distance(origin, origin) == 0
    end

    @testset "ring wraps" begin
        ring = ring_co(SeededPrng(12), STRING_N)
        mu = standard_distance(STRING_N)
        origin = at(ring, 0)
        @test isapprox(distance(origin, at(ring, 0.5)) / mu, 1; atol = 0.06)          # opposite side is μ
        @test distance(origin, at(ring, 0.98)) < distance(origin, at(ring, 0.25))      # 0.98 is next to 0
        @test distance(at(ring, 0.3), at(ring, 1.3)) == 0                             # t is taken mod 1
    end

    @testset "plane is isotropic" begin
        plane = plane_co(SeededPrng(13), STRING_N)
        origin = at(plane, 0.5, 0.5)
        along_x = distance(origin, at(plane, 0.8, 0.5))
        along_y = distance(origin, at(plane, 0.5, 0.8))
        diagonal = distance(origin, at(plane, 0.5 + 0.3 / sqrt(2), 0.5 + 0.3 / sqrt(2)))
        @test isapprox(along_x, along_y; atol = along_y * 0.15)
        @test isapprox(diagonal, along_x; atol = along_x * 0.2)
        @test distance(origin, at(plane, 0.55, 0.5)) < along_x
    end

    @testset "every position is a stranger to an unrelated point" begin
        prng = SeededPrng(14)
        line = line_co(prng, STRING_N)
        stranger = random_correlithm(prng, STRING_N)
        mu = standard_distance(STRING_N)
        for t in (0.0, 0.25, 0.5, 0.75, 1.0)
            @test isapprox(distance(at(line, t), stranger) / mu, 1; atol = 0.06)
        end
    end

    @testset "ordinal positions are evenly spaced" begin
        line = line_co(SeededPrng(15), STRING_N)
        a = at_index(line, 1, 26); b = at_index(line, 2, 26); e = at_index(line, 5, 26); z = at_index(line, 26, 26)
        @test distance(a, b) < distance(a, e) < distance(a, z)
    end

    @testset "same seed, same string" begin
        a = at(plane_co(SeededPrng(16), 64), 0.2, 0.7)
        b = at(plane_co(SeededPrng(16), 64), 0.2, 0.7)
        @test a == b
    end

    @testset "invalid arguments" begin
        line = line_co(SeededPrng(1), 8)
        plane = plane_co(SeededPrng(1), 8)
        @test_throws ArgumentError at(plane, 0.5)
        @test_throws ArgumentError at(line, 0.5, 0.5)
        @test_throws DomainError at(line, NaN)
        @test_throws DomainError at(plane, NaN, 0.5)
        @test_throws DomainError at_index(line, 0, 3)
        @test_throws DomainError at_index(line, 1, 0)
        @test_throws DomainError line_co(SeededPrng(1), 0)
    end
end

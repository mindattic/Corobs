# Table II-1 and Ch. III, checked against the cube itself.
_mean(xs) = sum(xs) / length(xs)

@testset "NCube" begin
    @testset "random points sit at standard distance with the book's deviation (N=$n)" for n in (64, 100)
        prng = SeededPrng(2004)
        ds = [distance(random_correlithm(prng, n), random_correlithm(prng, n)) for _ in 1:3000]
        m = _mean(ds)
        sd = sqrt(sum((d - m)^2 for d in ds) / (length(ds) - 1))
        @test isapprox(m, standard_distance(n); atol = 0.03)       # μ = √(N/6)
        @test isapprox(sd, STANDARD_DEVIATION; atol = 0.025)       # σ = √(7/120), independent of N
    end

    @testset "midpoint and corner distances match the table (N=$n)" for n in (64, 100)
        prng = SeededPrng(7)
        mid = midpoint(n)
        corner = Correlithm(zeros(n))
        to_mid = Float64[]; to_corner = Float64[]
        for _ in 1:2000
            p = random_correlithm(prng, n)
            push!(to_mid, distance(p, mid))
            push!(to_corner, distance(p, corner))
        end
        @test isapprox(_mean(to_mid), standard_radius(n); atol = 0.02)
        @test isapprox(_mean(to_corner), standard_diameter(n); atol = 0.03)
        @test isapprox(half_diagonal(n), distance(mid, corner); atol = 1e-12)
    end

    @testset "bit content follows Eq. III-H" begin
        n = 100
        mu = standard_distance(n)
        @test bit_content(n, mu) == 0
        @test bit_content(n, mu + 1) == 0                                 # beyond μ carries nothing
        @test isapprox(bit_content(n, mu - 1), 24.75; atol = 0.1)         # the book's rounded form
        @test isapprox(bit_content(n, 0) / n, 4.12; atol = 0.02)          # a little over four bits per dimension
        @test isapprox(distance_for_bits(n, 24.75), mu - 1; atol = 0.005)
    end

    @testset "probability of proximity is two to the minus bits (Eq. III-J)" begin
        n = 100
        mu = standard_distance(n)
        @test probability_of_proximity(n, mu) == 1
        @test isapprox(log10(probability_of_proximity(n, mu - 0.5)), -1.86; atol = 0.02)
    end

    @testset "point capacity follows Eq. III-Q" begin
        @test isapprox(log10(point_capacity(96, 1.0)), 33.3; atol = 0.3)   # ≈ 10^33 points at N=96, d=1
        @test point_capacity(96, standard_distance(96)) == 1
    end

    @testset "deviations and distances round trip" begin
        n = 64
        d = distance_at_deviations(n, 6)
        @test isapprox(deviations_below(n, d), 6; atol = 1e-9)
        @test isapprox(bit_content(n, d), 36 / log(2); atol = 1e-9)        # 6σ ≈ 52 bits
    end

    @testset "invalid arguments" begin
        @test_throws DomainError standard_distance(0)
        @test_throws DomainError distance_for_bits(64, -1)
        @test_throws ArgumentError Correlithm(Float64[])
        @test_throws DomainError Correlithm([0.5, 1.5])
        @test_throws DomainError Correlithm([NaN])
        @test_throws ArgumentError distance(midpoint(3), midpoint(4))
        @test_throws DomainError interpolate(midpoint(3), midpoint(3), 1.5)
        @test_throws ArgumentError centroid(Correlithm[])
    end
end

const CONV_N = 128

@testset "Converters" begin
    @testset "cardinal values are fixed tokens at standard distance from each other" begin
        c = CardinalConverter(SeededPrng(1), CONV_N)
        again = CardinalConverter(SeededPrng(1), CONV_N)
        first = topoint(c, "Underclan")
        @test topoint(c, "Underclan") === first                  # a value is one token, cached
        @test topoint(again, "Underclan") == first               # same seed, same token, whatever was seen first
        mu = standard_distance(CONV_N)
        @test isapprox(distance(topoint(c, "Underclan"), topoint(c, "Arcturus")) / mu, 1; atol = 0.2)
        @test topoint(c, nothing) == midpoint(CONV_N)
        @test topoint(c, missing) == midpoint(CONV_N)
    end

    @testset "ordinal neighbours are closer than extremes and unknowns throw" begin
        tiers = ["street", "runner", "fixer", "corpo", "board"]
        c = OrdinalConverter(SeededPrng(2), CONV_N, tiers)
        @test distance(topoint(c, "street"), topoint(c, "runner")) < distance(topoint(c, "street"), topoint(c, "board"))
        @test_throws ArgumentError topoint(c, "god")
        @test topoint(c, nothing) == missingpoint(c)
        @test length(c) == 5
        @test_throws ArgumentError OrdinalConverter(SeededPrng(2), CONV_N, String[])
        @test_throws ArgumentError OrdinalConverter(SeededPrng(2), CONV_N, ["a", "a"])
    end

    @testset "continuous values interpolate and can wrap" begin
        years = ContinuousConverter(SeededPrng(3), CONV_N, 2200, 2300)
        @test distance(topoint(years, 2230), topoint(years, 2231)) < distance(topoint(years, 2230), topoint(years, 2290))
        @test topoint(years, nothing) == missingpoint(years)
        @test topoint(years, NaN) == missingpoint(years)

        hours = ContinuousConverter(SeededPrng(4), CONV_N, 0, 24; wraps = true)
        @test distance(topoint(hours, 23.5), topoint(hours, 0.5)) < distance(topoint(hours, 23.5), topoint(hours, 12))
        @test_throws ArgumentError ContinuousConverter(SeededPrng(4), CONV_N, 5, 5)
    end

    @testset "planar positions are near when the map says so" begin
        map = PlanarConverter(SeededPrng(5), CONV_N, -10, 10, -10, 10)
        here = topoint(map, (0.0, 0.0))
        @test distance(here, topoint(map, (0.5, 0.5))) < distance(here, topoint(map, (8.0, -7.0)))
        @test topoint(map, nothing) == missingpoint(map)
        @test topoint(map, (NaN, 1.0)) == missingpoint(map)
        @test_throws ArgumentError PlanarConverter(SeededPrng(5), CONV_N, 1, 0, -10, 10)
        @test dimensions(map) == CONV_N
    end
end

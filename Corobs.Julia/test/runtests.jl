using Test
using Corobs

@testset "Corobs" begin
    include("ncube.jl")
    include("seeded_prng.jl")
    include("string_co.jl")
    include("converters.jl")
    include("mining.jl")
    include("bench.jl")
    include("bugs.jl")
    include("conformance.jl")
    include("purity.jl")
end

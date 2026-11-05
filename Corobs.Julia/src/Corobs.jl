"""
    Corobs

COROBS: Correlithm Object technology (P. Nick Lawrence, *Correlithm Object Technology*, 2004) as a
pure, deterministic Julia package. A port of the C# reference implementation (`Corobs.Csharp`) that
reproduces it bit for bit under the same seed (see `conformance/README.md`).
"""
module Corobs

include("Seeding.jl")
include("Geometry.jl")
include("StringCOs.jl")
include("Converters.jl")
include("Mining.jl")
include("Bench.jl")

using .Seeding
using .Geometry
using .StringCOs
using .Converters
using .Mining
using .Bench

export Seeding, Geometry, StringCOs, Converters, Mining, Bench
export SeededPrng, next_uint64!, next_double!, next_int!, derive
export STANDARD_DEVIATION, RADIUS_DEVIATION, DIAMETER_DEVIATION,
    standard_distance, standard_radius, standard_diameter, corner_distance, half_diagonal,
    major_diagonal, deviations_below, distance_at_deviations, bit_content, distance_for_bits,
    probability_of_proximity, point_capacity
export Correlithm, random_correlithm, midpoint, dimensions, coordinates, squared_distance,
    distance, interpolate, centroid, superpose
export StringCO, line_co, ring_co, plane_co, at, at_index
export Converter, CardinalConverter, OrdinalConverter, ContinuousConverter, PlanarConverter,
    topoint, missingpoint
export PlyPoint, Pattern, PatternMiner, Rule, RuleMiner, Hit, Cue, mine, find_hits
export RecallResult, ReachResult, holdout_recall, reach, cascade_yield

end

# conformance/vectors.json: the C# reference's exact outputs. Hex strings are IEEE-754 bits and must
# match exactly; JSON numbers (statistics through log/pow) match to 1e-12 relative. See
# conformance/README.md for the schema.
using JSON

const VECTORS = JSON.parsefile(joinpath(@__DIR__, "..", "..", "conformance", "vectors.json"))

_hexbits(s::AbstractString) = parse(UInt64, s; base = 16)
_hexd(s::AbstractString) = reinterpret(Float64, _hexbits(s))
_bits(x::Float64) = reinterpret(UInt64, x)
_bits(p::Correlithm) = [reinterpret(UInt64, v) for v in coordinates(p)]
_hexbits(arr::AbstractVector) = [_hexbits(s) for s in arr]
_close(a, b) = a == b || abs(a - b) <= 1e-12 * max(abs(a), abs(b)) || abs(a - b) <= 1e-300

@testset "Conformance" begin
    @testset "prng" begin
        for case in VECTORS["prng"]
            seed = parse(Int64, case["seed"])
            u = SeededPrng(seed)
            @test [next_uint64!(u) for _ in 1:8] == [parse(UInt64, s) for s in case["uint64"]]
            d = SeededPrng(seed)
            @test [_bits(next_double!(d)) for _ in 1:8] == _hexbits(case["doubles"])
            for nx in case["next"]
                p = SeededPrng(seed)
                @test [next_int!(p, nx["max"]) for _ in 1:8] == Int.(nx["values"])
            end
        end
    end

    @testset "derive" begin
        for case in VECTORS["derive"]
            child = derive(SeededPrng(parse(Int64, case["seed"])), case["label"])
            @test child.seed == parse(Int64, case["childSeed"])
            @test next_uint64!(child) == parse(UInt64, case["firstUint64"])
            @test derive(child, "x").seed == parse(Int64, case["grandchildSeed"])
        end
    end

    @testset "ncube" begin
        nc = VECTORS["ncube"]
        @test _close(STANDARD_DEVIATION, nc["standardDeviation"])
        @test _close(RADIUS_DEVIATION, nc["radiusDeviation"])
        @test _close(DIAMETER_DEVIATION, nc["diameterDeviation"])
        for case in nc["cases"]
            n = case["n"]
            @test _close(standard_distance(n), case["standardDistance"])
            @test _close(standard_radius(n), case["standardRadius"])
            @test _close(standard_diameter(n), case["standardDiameter"])
            @test _close(corner_distance(n), case["cornerDistance"])
            @test _close(half_diagonal(n), case["halfDiagonal"])
            @test _close(major_diagonal(n), case["majorDiagonal"])
            for d in case["distances"]
                x = Float64(d["distance"])
                @test _close(deviations_below(n, x), d["deviationsBelow"])
                @test _close(bit_content(n, x), d["bitContent"])
                @test _close(probability_of_proximity(n, x), d["probabilityOfProximity"])
                @test _close(point_capacity(n, x), d["pointCapacity"])
            end
            for b in case["bitsToDistance"]
                @test _close(distance_for_bits(n, Float64(b["bits"])), b["distanceForBits"])
            end
            for k in case["distanceAtDeviations"]
                @test _close(distance_at_deviations(n, Float64(k["deviations"])), k["distance"])
            end
        end
    end

    @testset "correlithm" begin
        c = VECTORS["correlithm"]
        n = c["dimensions"]
        prng = SeededPrng(parse(Int64, c["seed"]))
        a = random_correlithm(prng, n)
        b = random_correlithm(prng, n)
        mid = midpoint(n)
        @test _bits(a) == _hexbits(c["a"])
        @test _bits(b) == _hexbits(c["b"])
        @test _bits(mid) == _hexbits(c["midpoint"])
        @test _bits(squared_distance(a, b)) == _hexbits(c["squaredDistance"])
        @test _bits(distance(a, b)) == _hexbits(c["distance"])
        @test _bits(centroid([a, b, mid])) == _hexbits(c["centroidOfABMidpoint"])
        for f in c["interpolate"]
            @test _bits(interpolate(a, b, Float64(f["fraction"]))) == _hexbits(f["point"])
        end
    end

    @testset "strings" begin
        s = VECTORS["strings"]
        n = s["dimensions"]
        line = line_co(SeededPrng(parse(Int64, s["line"]["seed"])), n)
        ring = ring_co(SeededPrng(parse(Int64, s["ring"]["seed"])), n)
        plane = plane_co(SeededPrng(parse(Int64, s["plane"]["seed"])), n)
        for (str, key) in ((line, "line"), (ring, "ring"))
            for case in s[key]["at"]
                @test _bits(at(str, _hexd(case["t"]))) == _hexbits(case["point"])
            end
            for case in s[key]["atIndex"]
                @test _bits(at_index(str, case["index"] + 1, case["count"])) == _hexbits(case["point"])
            end
        end
        for case in s["line"]["atIndexSingle"]
            @test _bits(at_index(line, case["index"] + 1, case["count"])) == _hexbits(case["point"])
        end
        for case in s["plane"]["at"]
            @test _bits(at(plane, _hexd(case["x"]), _hexd(case["y"]))) == _hexbits(case["point"])
        end
    end

    @testset "converters" begin
        cv = VECTORS["converters"]
        n = cv["dimensions"]
        @test _bits(midpoint(n)) == _hexbits(cv["missing"])

        cardinal = CardinalConverter(SeededPrng(parse(Int64, cv["cardinal"]["seed"])), n)
        for case in cv["cardinal"]["cases"]
            @test _bits(topoint(cardinal, case["value"])) == _hexbits(case["point"])
        end

        ord = cv["ordinal"]
        ordinal = OrdinalConverter(SeededPrng(parse(Int64, ord["seed"])), n, String.(ord["order"]))
        for case in ord["cases"]
            @test _bits(topoint(ordinal, case["value"])) == _hexbits(case["point"])
        end

        for key in ("continuousLine", "continuousRing")
            spec = cv[key]
            conv = ContinuousConverter(SeededPrng(parse(Int64, spec["seed"])), n, spec["min"], spec["max"];
                wraps = spec["wraps"])
            for case in spec["cases"]
                @test _bits(topoint(conv, _hexd(case["value"]))) == _hexbits(case["point"])
            end
        end

        pl = cv["planar"]
        planar = PlanarConverter(SeededPrng(parse(Int64, pl["seed"])), n, pl["minX"], pl["maxX"], pl["minY"], pl["maxY"])
        for case in pl["cases"]
            @test _bits(topoint(planar, (_hexd(case["x"]), _hexd(case["y"])))) == _hexbits(case["point"])
        end
    end

    @testset "mining" begin
        m = VECTORS["mining"]
        ply(name) = [PlyPoint(Int(e["id"]), Correlithm([_hexd(s) for s in e["point"]])) for e in m["plies"][name]]
        faction = ply("faction"); turf = ply("turf")
        miner = PatternMiner(min_deviations = m["patternMiner"]["minDeviations"], min_members = m["patternMiner"]["minMembers"])
        patterns = Dict("faction" => mine(miner, faction), "turf" => mine(miner, turf))
        for name in ("faction", "turf")
            expected = m["patterns"][name]
            actual = patterns[name]
            @test length(actual) == length(expected)
            for (p, e) in zip(actual, expected)
                @test p.members == Int.(e["members"])
                @test _bits(p.centroid) == _hexbits(e["centroid"])
                @test _bits(p.radius) == _hexbits(e["radius"])
                @test _bits(p.mean_pair_distance) == _hexbits(e["meanPairDistance"])
                @test _close(p.bits, e["bits"])
            end
        end

        rules = mine(RuleMiner(min_support = m["ruleMiner"]["minSupport"]), "faction", patterns["faction"], "turf", patterns["turf"])
        @test length(rules) == length(m["rules"])
        for (r, e) in zip(rules, m["rules"])
            @test r.source_ply == e["sourcePly"]
            @test r.target_ply == e["targetPly"]
            @test findfirst(p -> p === r.source, patterns["faction"]) - 1 == e["sourcePattern"]
            @test findfirst(p -> p === r.target, patterns["turf"]) - 1 == e["targetPattern"]
            @test _close(r.support, e["support"])
            @test _close(r.bits, e["bits"])
        end

        plies = Dict("faction" => Dict(p.id => p.point for p in faction), "turf" => Dict(p.id => p.point for p in turf))
        hits = find_hits(Cue(target_deviations = m["cue"]["targetDeviations"]), rules, plies)
        @test length(hits) == length(m["hits"])
        for (h, e) in zip(hits, m["hits"])
            @test h.id == e["id"]
            @test findfirst(r -> r === h.rule, rules) - 1 == e["rule"]
            @test _bits(h.source_distance) == _hexbits(e["sourceDistance"])
            @test _bits(h.target_distance) == _hexbits(e["targetDistance"])
            @test _close(h.bits, e["bits"])
            @test h.rank == e["rank"]
        end
    end

    @testset "bench" begin
        bv = VECTORS["bench"]
        pairs = [(Int(p[1]), Int(p[2])) for p in bv["pairs"]]
        predictor(name) = id -> Int.(get(bv["predictors"][name], string(id), Any[]))
        for case in bv["holdoutRecall"]
            r = holdout_recall(pairs, Float64(case["holdoutFraction"]), parse(Int64, case["seed"]), predictor(case["predictor"]))
            e = case["result"]
            @test (r.hidden, r.recovered, r.predicted, r.predicted_true) ==
                  (e["hidden"], e["recovered"], e["predicted"], e["predictedTrue"])
        end

        rc = bv["reach"]
        adjacency = Dict(parse(Int, k) => Int.(v) for (k, v) in rc["adjacency"])
        r = reach(sort(collect(keys(adjacency))), id -> adjacency[id], rc["maxHops"])
        @test length(r.mean_reachable_by_hop) == length(rc["meanReachableByHop"])
        @test all(_close(a, b) for (a, b) in zip(r.mean_reachable_by_hop, rc["meanReachableByHop"]))
        @test r.isolated == rc["isolated"]
        @test r.total == rc["total"]

        for case in bv["cascadeYield"]
            @test _close(cascade_yield(case["closedByCascade"], case["directFixes"]), case["yield"])
        end
    end
end

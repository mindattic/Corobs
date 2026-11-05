import Corobs
import Foundation
import Testing

/// conformance/vectors.json is the C# reference's exact output; this port must reproduce it. Hex
/// strings are IEEE-754 bits compared exactly; JSON numbers pass through log/pow and compare to
/// 1e-12 relative. See conformance/README.md.
@Suite struct ConformanceTests {
    @Test func prng() throws {
        let v = try loadVectors()
        var bad: [String] = []
        for c in jArr(v["prng"]).map(jObj) {
            let seed = Int64(jStr(c["seed"]))!
            let u = SeededPrng(seed)
            for (i, e) in jArr(c["uint64"]).enumerated() {
                if u.nextUInt64() != UInt64(jStr(e))! { bad.append("seed \(seed) uint64[\(i)]") }
            }
            let d = SeededPrng(seed)
            for (i, e) in jArr(c["doubles"]).enumerated() {
                if !sameBits(d.nextDouble(), e) { bad.append("seed \(seed) doubles[\(i)]") }
            }
            for nx in jArr(c["next"]).map(jObj) {
                let max = jInt(nx["max"])
                let p = SeededPrng(seed)
                for (i, e) in jArr(nx["values"]).enumerated() {
                    if try p.next(max) != jInt(e) { bad.append("seed \(seed) next(\(max))[\(i)]") }
                }
            }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func derive() throws {
        let v = try loadVectors()
        var bad: [String] = []
        for c in jArr(v["derive"]).map(jObj) {
            let seed = Int64(jStr(c["seed"]))!
            let label = jStr(c["label"])
            let child = SeededPrng(seed).derive(label)
            if child.seed != Int64(jStr(c["childSeed"]))! { bad.append("\(seed)/\(label) childSeed") }
            if child.nextUInt64() != UInt64(jStr(c["firstUint64"]))! { bad.append("\(seed)/\(label) firstUint64") }
            if child.derive("x").seed != Int64(jStr(c["grandchildSeed"]))! { bad.append("\(seed)/\(label) grandchildSeed") }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func ncube() throws {
        let v = jObj(try loadVectors()["ncube"])
        var bad: [String] = []
        func check(_ name: String, _ actual: Double, _ expected: Any?) {
            if !close(actual, jNum(expected)) { bad.append("\(name): \(actual) vs \(jNum(expected))") }
        }
        check("standardDeviation", NCube.standardDeviation, v["standardDeviation"])
        check("radiusDeviation", NCube.radiusDeviation, v["radiusDeviation"])
        check("diameterDeviation", NCube.diameterDeviation, v["diameterDeviation"])
        for c in jArr(v["cases"]).map(jObj) {
            let n = jInt(c["n"])
            check("N=\(n) standardDistance", try NCube.standardDistance(n), c["standardDistance"])
            check("N=\(n) standardRadius", try NCube.standardRadius(n), c["standardRadius"])
            check("N=\(n) standardDiameter", try NCube.standardDiameter(n), c["standardDiameter"])
            check("N=\(n) cornerDistance", try NCube.cornerDistance(n), c["cornerDistance"])
            check("N=\(n) halfDiagonal", try NCube.halfDiagonal(n), c["halfDiagonal"])
            check("N=\(n) majorDiagonal", try NCube.majorDiagonal(n), c["majorDiagonal"])
            for e in jArr(c["distances"]).map(jObj) {
                let d = jNum(e["distance"])
                check("N=\(n) d=\(d) deviationsBelow", try NCube.deviationsBelow(n, d), e["deviationsBelow"])
                check("N=\(n) d=\(d) bitContent", try NCube.bitContent(n, d), e["bitContent"])
                check("N=\(n) d=\(d) probabilityOfProximity", try NCube.probabilityOfProximity(n, d), e["probabilityOfProximity"])
                check("N=\(n) d=\(d) pointCapacity", try NCube.pointCapacity(n, d), e["pointCapacity"])
            }
            for e in jArr(c["bitsToDistance"]).map(jObj) {
                check("N=\(n) distanceForBits", try NCube.distanceForBits(n, jNum(e["bits"])), e["distanceForBits"])
            }
            for e in jArr(c["distanceAtDeviations"]).map(jObj) {
                check("N=\(n) distanceAtDeviations", try NCube.distanceAtDeviations(n, jNum(e["deviations"])), e["distance"])
            }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func correlithm() throws {
        let c = jObj(try loadVectors()["correlithm"])
        let prng = SeededPrng(Int64(jStr(c["seed"]))!)
        let n = jInt(c["dimensions"])
        let a = try Correlithm.random(prng, dimensions: n)
        let b = try Correlithm.random(prng, dimensions: n)
        let mid = try Correlithm.midpoint(n)
        #expect(samePoint(a, c["a"]))
        #expect(samePoint(b, c["b"]))
        #expect(samePoint(mid, c["midpoint"]))
        #expect(sameBits(try a.squaredDistance(to: b), c["squaredDistance"]))
        #expect(sameBits(try a.distance(to: b), c["distance"]))
        #expect(samePoint(try Correlithm.centroid([a, b, mid]), c["centroidOfABMidpoint"]))
        for e in jArr(c["interpolate"]).map(jObj) {
            let f = jNum(e["fraction"])
            #expect(samePoint(try a.interpolate(toward: b, fraction: f), e["point"]), "interpolate \(f)")
        }
    }

    @Test func strings() throws {
        let s = jObj(try loadVectors()["strings"])
        let n = jInt(s["dimensions"])
        var bad: [String] = []

        let lineV = jObj(s["line"])
        let line = try StringCo.line(SeededPrng(Int64(jStr(lineV["seed"]))!), dimensions: n)
        for e in jArr(lineV["at"]).map(jObj) {
            if !samePoint(try line.at(bits(e["t"])), e["point"]) { bad.append("line at \(bits(e["t"]))") }
        }
        for key in ["atIndex", "atIndexSingle"] {
            for e in jArr(lineV[key]).map(jObj) {
                if !samePoint(try line.atIndex(jInt(e["index"]), count: jInt(e["count"])), e["point"]) { bad.append("line \(key) \(jInt(e["index"]))/\(jInt(e["count"]))") }
            }
        }

        let ringV = jObj(s["ring"])
        let ring = try StringCo.ring(SeededPrng(Int64(jStr(ringV["seed"]))!), dimensions: n)
        for e in jArr(ringV["at"]).map(jObj) {
            if !samePoint(try ring.at(bits(e["t"])), e["point"]) { bad.append("ring at \(bits(e["t"]))") }
        }
        for e in jArr(ringV["atIndex"]).map(jObj) {
            if !samePoint(try ring.atIndex(jInt(e["index"]), count: jInt(e["count"])), e["point"]) { bad.append("ring atIndex \(jInt(e["index"]))") }
        }

        let planeV = jObj(s["plane"])
        let plane = try StringCo.plane(SeededPrng(Int64(jStr(planeV["seed"]))!), dimensions: n)
        for e in jArr(planeV["at"]).map(jObj) {
            if !samePoint(try plane.at(x: bits(e["x"]), y: bits(e["y"])), e["point"]) { bad.append("plane at (\(bits(e["x"])), \(bits(e["y"])))") }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func converters() throws {
        let cv = jObj(try loadVectors()["converters"])
        let n = jInt(cv["dimensions"])
        var bad: [String] = []
        #expect(samePoint(try Correlithm.midpoint(n), cv["missing"]))

        let cardV = jObj(cv["cardinal"])
        let cardinal = try CardinalConverter<String>(SeededPrng(Int64(jStr(cardV["seed"]))!), dimensions: n)
        for e in jArr(cardV["cases"]).map(jObj) {
            if !samePoint(try cardinal.convert(jStr(e["value"])), e["point"]) { bad.append("cardinal '\(jStr(e["value"]))'") }
        }

        let ordV = jObj(cv["ordinal"])
        let order = jArr(ordV["order"]).map(jStr)
        let ordinal = try OrdinalConverter(SeededPrng(Int64(jStr(ordV["seed"]))!), dimensions: n, order: order)
        for e in jArr(ordV["cases"]).map(jObj) {
            if !samePoint(try ordinal.convert(jStr(e["value"])), e["point"]) { bad.append("ordinal '\(jStr(e["value"]))'") }
        }

        for name in ["continuousLine", "continuousRing"] {
            let c = jObj(cv[name])
            let conv = try ContinuousConverter(SeededPrng(Int64(jStr(c["seed"]))!), dimensions: n,
                                               min: jNum(c["min"]), max: jNum(c["max"]), wraps: name == "continuousRing")
            for e in jArr(c["cases"]).map(jObj) {
                if !samePoint(try conv.convert(bits(e["value"])), e["point"]) { bad.append("\(name) \(bits(e["value"]))") }
            }
        }

        let plV = jObj(cv["planar"])
        let planar = try PlanarConverter(SeededPrng(Int64(jStr(plV["seed"]))!), dimensions: n,
                                         minX: jNum(plV["minX"]), maxX: jNum(plV["maxX"]),
                                         minY: jNum(plV["minY"]), maxY: jNum(plV["maxY"]))
        for e in jArr(plV["cases"]).map(jObj) {
            if !samePoint(try planar.convert((x: bits(e["x"]), y: bits(e["y"]))), e["point"]) { bad.append("planar (\(bits(e["x"])), \(bits(e["y"])))") }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func mining() throws {
        let m = jObj(try loadVectors()["mining"])
        func ply(_ name: String) throws -> [PlyPoint<Int>] {
            try jArr(jObj(m["plies"])[name]).map(jObj).map { e in PlyPoint(id: jInt(e["id"]), point: try point(e["point"])) }
        }
        let faction = try ply("faction")
        let turf = try ply("turf")
        let pm = jObj(m["patternMiner"])
        let miner = try PatternMiner(minDeviations: jNum(pm["minDeviations"]), minMembers: jInt(pm["minMembers"]))
        let fp = try miner.mine(faction)
        let tp = try miner.mine(turf)

        var bad: [String] = []
        for (name, actual) in [("faction", fp), ("turf", tp)] {
            let expected = jArr(jObj(m["patterns"])[name]).map(jObj)
            if expected.count != actual.count { bad.append("\(name): \(actual.count) patterns, expected \(expected.count)"); continue }
            for (i, (e, p)) in zip(expected, actual).enumerated() {
                if p.members != jArr(e["members"]).map(jInt) { bad.append("\(name)[\(i)] members \(p.members)") }
                if !samePoint(p.centroid, e["centroid"]) { bad.append("\(name)[\(i)] centroid") }
                if !sameBits(p.radius, e["radius"]) { bad.append("\(name)[\(i)] radius") }
                if !sameBits(p.meanPairDistance, e["meanPairDistance"]) { bad.append("\(name)[\(i)] meanPairDistance") }
                if !close(p.bits, jNum(e["bits"])) { bad.append("\(name)[\(i)] bits") }
            }
        }

        let rules = try RuleMiner(minSupport: jNum(jObj(m["ruleMiner"])["minSupport"]))
            .mine(sourcePly: "faction", source: fp, targetPly: "turf", target: tp)
        let expectedRules = jArr(m["rules"]).map(jObj)
        if expectedRules.count != rules.count { bad.append("\(rules.count) rules, expected \(expectedRules.count)") }
        for (i, (e, r)) in zip(expectedRules, rules).enumerated() {
            if r.sourcePly != jStr(e["sourcePly"]) || r.targetPly != jStr(e["targetPly"]) { bad.append("rule[\(i)] plies") }
            if r.source !== fp[jInt(e["sourcePattern"])] { bad.append("rule[\(i)] source pattern") }
            if r.target !== tp[jInt(e["targetPattern"])] { bad.append("rule[\(i)] target pattern") }
            if !close(r.support, jNum(e["support"])) { bad.append("rule[\(i)] support") }
            if !close(r.bits, jNum(e["bits"])) { bad.append("rule[\(i)] bits") }
        }

        let plies: [String: [Int: Correlithm]] = [
            "faction": Dictionary(uniqueKeysWithValues: faction.map { ($0.id, $0.point) }),
            "turf": Dictionary(uniqueKeysWithValues: turf.map { ($0.id, $0.point) }),
        ]
        let hits = try Cue(targetDeviations: jNum(jObj(m["cue"])["targetDeviations"])).find(rules, plies: plies)
        let expectedHits = jArr(m["hits"]).map(jObj)
        if expectedHits.count != hits.count { bad.append("\(hits.count) hits, expected \(expectedHits.count)") }
        for (i, (e, h)) in zip(expectedHits, hits).enumerated() {
            let rule = rules[jInt(e["rule"])]
            if h.id != jInt(e["id"]) { bad.append("hit[\(i)] id \(h.id)") }
            if h.rule.source !== rule.source || h.rule.target !== rule.target { bad.append("hit[\(i)] rule") }
            if !sameBits(h.sourceDistance, e["sourceDistance"]) { bad.append("hit[\(i)] sourceDistance") }
            if !sameBits(h.targetDistance, e["targetDistance"]) { bad.append("hit[\(i)] targetDistance") }
            if !close(h.bits, jNum(e["bits"])) { bad.append("hit[\(i)] bits") }
            if h.rank != jInt(e["rank"]) { bad.append("hit[\(i)] rank") }
        }
        #expect(bad.isEmpty, "\(bad.prefix(10))")
    }

    @Test func bench() throws {
        let b = jObj(try loadVectors()["bench"])
        let pairs: [(Int, Int)] = jArr(b["pairs"]).map { let p = jArr($0); return (jInt(p[0]), jInt(p[1])) }
        let predictors = jObj(b["predictors"])
        func table(_ name: String) -> [Int: [Int]] {
            var t: [Int: [Int]] = [:]
            for (k, value) in jObj(predictors[name]) { t[Int(k)!] = jArr(value).map(jInt) }
            return t
        }
        for c in jArr(b["holdoutRecall"]).map(jObj) {
            let name = jStr(c["predictor"])
            let t = table(name)
            let r = try Bench.holdoutRecall(pairs, holdoutFraction: jNum(c["holdoutFraction"]),
                                            seed: Int64(jStr(c["seed"]))!) { t[$0] ?? [] }
            let e = jObj(c["result"])
            let expected = RecallResult(hidden: jInt(e["hidden"]), recovered: jInt(e["recovered"]),
                                        predicted: jInt(e["predicted"]), predictedTrue: jInt(e["predictedTrue"]))
            #expect(r == expected, "\(name) \(jNum(c["holdoutFraction"]))")
        }

        let reachV = jObj(b["reach"])
        var adjacency: [Int: [Int]] = [:]
        for (k, value) in jObj(reachV["adjacency"]) { adjacency[Int(k)!] = jArr(value).map(jInt) }
        let ids = adjacency.keys.sorted()
        let reach = try Bench.reach(ids, maxHops: jInt(reachV["maxHops"])) { adjacency[$0] ?? [] }
        let means = jArr(reachV["meanReachableByHop"]).map(jNum)
        #expect(reach.meanReachableByHop.count == means.count)
        for (actual, expected) in zip(reach.meanReachableByHop, means) { #expect(close(actual, expected)) }
        #expect(reach.isolated == jInt(reachV["isolated"]))
        #expect(reach.total == jInt(reachV["total"]))

        for c in jArr(b["cascadeYield"]).map(jObj) {
            let y = Bench.cascadeYield(closedByCascade: jInt(c["closedByCascade"]), directFixes: jInt(c["directFixes"]))
            #expect(close(y, jNum(c["yield"])))
        }
    }
}

// MARK: - Reading the vectors

private func loadVectors() throws -> [String: Any] {
    let url = packageDirectory.deletingLastPathComponent()
        .appendingPathComponent("conformance")
        .appendingPathComponent("vectors.json")
    let data = try Data(contentsOf: url)
    return jObj(try JSONSerialization.jsonObject(with: data))
}

private func jObj(_ a: Any?) -> [String: Any] { a as! [String: Any] }
private func jArr(_ a: Any?) -> [Any] { a as! [Any] }
private func jStr(_ a: Any?) -> String { a as! String }

private func jNum(_ a: Any?) -> Double {
    if let d = a as? Double { return d }
    if let i = a as? Int { return Double(i) }
    if let n = a as? NSNumber { return n.doubleValue }
    fatalError("not a number: \(String(describing: a))")
}

private func jInt(_ a: Any?) -> Int {
    if let i = a as? Int { return i }
    if let n = a as? NSNumber { return n.intValue }
    fatalError("not an integer: \(String(describing: a))")
}

/// A double from its IEEE-754 bits written as 16 hex digits.
private func bits(_ a: Any?) -> Double {
    Double(bitPattern: UInt64(jStr(a), radix: 16)!)
}

private func point(_ a: Any?) throws -> Correlithm {
    try Correlithm(jArr(a).map(bits))
}

private func sameBits(_ actual: Double, _ expected: Any?) -> Bool {
    actual.bitPattern == UInt64(jStr(expected), radix: 16)!
}

private func samePoint(_ actual: Correlithm, _ expected: Any?) -> Bool {
    let e = jArr(expected)
    return e.count == actual.dimensions && zip(actual.coordinates, e).allSatisfy { sameBits($0, $1) }
}

/// Relative error ≤ 1e-12, or absolute ≤ 1e-300 near zero (conformance/README.md).
private func close(_ actual: Double, _ expected: Double) -> Bool {
    if actual == expected { return true }
    let diff = abs(actual - expected)
    return diff <= 1e-12 * max(abs(actual), abs(expected)) || diff <= 1e-300
}

import pytest

from corobs import Correlithm, Cue, NCube, PatternMiner, PlyPoint, RuleMiner, SeededPrng

N = 64


def near(centre: Correlithm, prng: SeededPrng, jitter: float) -> Correlithm:
    c = []
    for v in centre.coordinates:
        x = v + (prng.next_double() - 0.5) * 2 * jitter
        c.append(0.0 if x < 0 else 1.0 if x > 1 else x)
    return Correlithm(c)


def test_a_planted_cluster_among_random_points_is_the_only_pattern():
    prng = SeededPrng(100)
    points = [PlyPoint(i, Correlithm.random(prng, N)) for i in range(1000)]
    centre = Correlithm.random(prng, N)
    points += [PlyPoint(i, near(centre, prng, 0.05)) for i in range(1000, 1006)]

    patterns = PatternMiner(min_deviations=6, min_members=5).mine(points)

    assert len(patterns) == 1
    assert sorted(patterns[0].members) == list(range(1000, 1006))
    assert patterns[0].bits > NCube.bit_content(N, NCube.distance_at_deviations(N, 6))
    assert patterns[0].radius < patterns[0].mean_pair_distance


def test_random_points_alone_yield_no_pattern():
    prng = SeededPrng(101)
    points = [PlyPoint(i, Correlithm.random(prng, N)) for i in range(1500)]
    assert PatternMiner().mine(points) == []


def test_mining_is_deterministic():
    def make():
        p = SeededPrng(102)
        return [PlyPoint(i, near(Correlithm.midpoint(N), p, 0.05) if i < 8 else Correlithm.random(p, N)) for i in range(300)]

    a, b = PatternMiner().mine(make()), PatternMiner().mine(make())
    assert [p.members for p in a] == [p.members for p in b]
    assert [p.bits for p in a] == [p.bits for p in b]


def test_a_rule_emerges_and_the_one_member_that_breaks_it_is_the_top_hit():
    prng = SeededPrng(103)
    cs = Correlithm.random(prng, N)  # where the faction sits on ply s
    ct = Correlithm.random(prng, N)  # where its turf sits on ply t

    s = [PlyPoint(i, near(cs, prng, 0.05)) for i in range(1, 11)]  # ten members of one faction
    t = [PlyPoint(i, near(ct, prng, 0.05)) for i in range(1, 10)]  # nine share the turf
    t.append(PlyPoint(10, Correlithm.random(prng, N)))  # one lives somewhere unrelated
    for i in range(11, 41):
        s.append(PlyPoint(i, Correlithm.random(prng, N)))
        t.append(PlyPoint(i, Correlithm.random(prng, N)))

    miner = PatternMiner()
    ps, pt = miner.mine(s), miner.mine(t)
    assert len(ps) == 1 and len(pt) == 1

    rules = RuleMiner(0.8).mine("faction", ps, "turf", pt)
    assert len(rules) == 1
    assert rules[0].support == pytest.approx(0.9, abs=1e-9)

    plies = {"faction": {p.id: p.point for p in s}, "turf": {p.id: p.point for p in t}}
    hits = Cue().find(rules, plies)
    assert len(hits) == 1
    assert hits[0].id == 10
    assert hits[0].rank == 1
    assert hits[0].bits > 0
    assert hits[0].target_distance > NCube.distance_at_deviations(N, 1)


def test_a_rule_needs_support():
    prng = SeededPrng(104)
    cs, ct = Correlithm.random(prng, N), Correlithm.random(prng, N)
    s = [PlyPoint(i, near(cs, prng, 0.05)) for i in range(1, 11)]
    t = [PlyPoint(i, near(ct, prng, 0.05)) for i in range(1, 6)]
    t += [PlyPoint(i, Correlithm.random(prng, N)) for i in range(6, 11)]
    miner = PatternMiner()
    assert RuleMiner(0.8).mine("a", miner.mine(s), "b", miner.mine(t)) == [], "half the members is not a rule"
    with pytest.raises(ValueError):
        RuleMiner().mine("a", miner.mine(s), "a", miner.mine(t))


def test_parameters_are_validated():
    with pytest.raises(ValueError):
        PatternMiner(min_deviations=0)
    with pytest.raises(ValueError):
        PatternMiner(min_members=1)
    with pytest.raises(ValueError):
        RuleMiner(0)
    with pytest.raises(ValueError):
        Cue(-1)
    with pytest.raises(ValueError):
        Cue().find([_dummy_rule()], {})


def _dummy_rule():
    from corobs import Pattern, Rule
    p = Pattern([1], Correlithm.midpoint(2), 0.0, 0.0, 0.0)
    return Rule("a", p, "b", p, 1.0, 0.0)

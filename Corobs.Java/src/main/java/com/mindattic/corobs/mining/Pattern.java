package com.mindattic.corobs.mining;

import com.mindattic.corobs.Equality;
import com.mindattic.corobs.geometry.Correlithm;

import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** An emergent truth: things whose points on one ply lie far closer together than chance allows. What it means,
 *  and whether it is true, is the caller's hand decision. */
public final class Pattern<TId> {
    private final List<TId> members;
    private final Correlithm centroid;
    private final double radius, meanPairDistance, bits;
    private final Equality<? super TId> equality;
    private final Set<Equality.Key<TId>> set = new HashSet<>();

    /** A pattern over the given members and their already-computed geometry. */
    public Pattern(List<TId> members, Correlithm centroid, double radius, double meanPairDistance, double bits,
                   Equality<? super TId> equality) {
        this.members = List.copyOf(members);
        this.centroid = centroid;
        this.radius = radius;
        this.meanPairDistance = meanPairDistance;
        this.bits = bits;
        this.equality = equality != null ? equality : Equality.natural();
        for (TId m : members) set.add(new Equality.Key<>(m, this.equality));
    }

    /** The ids of the things in this cluster. */
    public List<TId> members() { return members; }

    /** The mean point of the members. */
    public Correlithm centroid() { return centroid; }

    /** The furthest any member lies from the centroid. */
    public double radius() { return radius; }

    /** The mean distance between members, pairwise. */
    public double meanPairDistance() { return meanPairDistance; }

    /** Eq. III-H bits of the mean pair distance. */
    public double bits() { return bits; }

    /** Whether {@code id} is one of this pattern's members. */
    public boolean contains(TId id) { return set.contains(new Equality.Key<>(id, equality)); }

    @Override
    public String toString() { return String.format(Locale.ROOT, "Pattern[%d members, %.1f bits]", members.size(), bits); }
}

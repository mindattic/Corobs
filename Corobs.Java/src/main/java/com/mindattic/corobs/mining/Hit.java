package com.mindattic.corobs.mining;

import java.util.Locale;

/** A ranked contradiction candidate: a thing inside a rule's source pattern that lies at or near standard distance
 *  from the rule's target (Ch. X–XI). What to do about it is the caller's hand decision. */
public record Hit<TId>(TId id, Rule<TId> rule, double sourceDistance, double targetDistance, double bits, int rank) {

    /** This hit with another rank. */
    public Hit<TId> withRank(int rank) { return new Hit<>(id, rule, sourceDistance, targetDistance, bits, rank); }

    @Override
    public String toString() { return String.format(Locale.ROOT, "#%d %s: %.1f bits — %s", rank, id, bits, rule); }
}

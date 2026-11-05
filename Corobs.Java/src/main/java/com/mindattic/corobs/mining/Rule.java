package com.mindattic.corobs.mining;

import java.util.Locale;

/** A rule {@code s.p >: t.q} (Ch. IV): things inside pattern {@code source} on ply {@code sourcePly} are found
 *  inside pattern {@code target} on ply {@code targetPly} with the given support. */
public record Rule<TId>(String sourcePly, Pattern<TId> source, String targetPly, Pattern<TId> target, double support, double bits) {
    @Override
    public String toString() {
        return String.format(Locale.ROOT, "%s.[%d] >: %s.[%d] support %.0f%%, %.1f bits",
                sourcePly, source.members().size(), targetPly, target.members().size(), support * 100, bits);
    }
}

package com.mindattic.corobs.bench;

/** How well a neighbour function recovers relationships that were hidden from it. */
public record RecallResult(int hidden, int recovered, int predicted, int predictedTrue) {

    /** Share of the hidden pairs that the predictor recovered. */
    public double recall() { return hidden == 0 ? 0 : recovered / (double) hidden; }

    /** Share of the predictor's own guesses that were actually true (anywhere in the full truth). */
    public double precision() { return predicted == 0 ? 0 : predictedTrue / (double) predicted; }
}

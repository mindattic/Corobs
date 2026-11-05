package com.mindattic.corobs.bench;

import java.util.List;

/** How far a thing can reach through a relationship: mean reachable count per hop and how many things reach
 *  nothing at all (dead records). */
public record ReachResult(List<Double> meanReachableByHop, int isolated, int total) {}

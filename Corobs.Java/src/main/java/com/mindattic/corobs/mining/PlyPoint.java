package com.mindattic.corobs.mining;

import com.mindattic.corobs.geometry.Correlithm;

/** One thing's position on one ply (subspace). */
public record PlyPoint<TId>(TId id, Correlithm point) {}

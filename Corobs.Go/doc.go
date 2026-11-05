// Package corobs is the Go port of COROBS (COrrelation + algoRithm OBjectS): a pure, deterministic
// implementation of Correlithm Object technology as set out in Dr. P. Nick Lawrence's
// "Correlithm Object Technology" (2004). Chapter, table and equation numbers in this module refer
// to that book.
//
// The C# library in Corobs.Csharp is the reference implementation; this port reproduces it bit for
// bit under the same seed, which conformance_test.go checks against ../conformance/vectors.json.
//
// The library lives in subpackages:
//
//   - seeding: SeededPrng, xoshiro256** under one seed, with labelled child streams
//   - geometry: NCube statistics (Table II-1, Eq. III-H/J/Q) and Correlithm points
//   - strco: string COs (Ch. VII), lines, rings and planes embedded in the cube
//   - converters: cardinal, ordinal, continuous and planar sensors (Ch. IX)
//   - mining: PatternMiner, RuleMiner and Cue (Ch. IV, X-XI)
//   - bench: hold-out recall, reach and cascade yield over abstract ids
//
// This package holds the sentinel errors the subpackages wrap. A non-positive dimension count, or
// measuring between points of different dimensionality, panics, as make does with a negative
// length; every other refusal is a returned error wrapping one of these.
package corobs

# Skip / convex-backend integration research

Grounding material for a future design plan exploring integration between
[Skip](https://skiplabs.io) (an incremental-computation language/engine,
local checkout at `~/src/skip`) and this repository. This is **not** a
proposal for "rewrite convex-backend in Skip" — that's out of scope. Instead
there are (at least) two orthogonal directions, to be planned and expanded
**separately**, not entangled:

1. **Skip as a convex client / observable reactive source**, consumed via
   skipruntime-ts, aiming for a tighter integration than the existing
   `billf/convex/adapter` branch (in the `~/src/skip` repo).
2. **convex-backend natively supporting Skip** (the language/engine) for
   building composable queries, filters, mappers, and running triggers,
   exported via the convex-backend API.

A separate session (using Codex) is independently drafting a plan for this
space in parallel. These docs are Haiku-generated research notes gathered
ahead of that plan landing, so the eventual planning/refinement pass (done
with higher-quality models, in small serialized steps) has grounding
material to start from rather than re-deriving it.

## Core finding to keep central in any plan

convex-backend's reactivity is **coarse invalidation, not incremental
computation**: read-sets are tracked and overlap-checked against writes, but
on invalidation the query is fully re-run rather than having deltas
propagated through it. Skip's reactive dataflow engine does the opposite —
`Reducer.add`/`.remove` give O(1) incremental updates (e.g. incrementing an
aggregate) instead of O(n) full re-scans, via a graph of memoized
`EagerCollection`/`LazyCollection` nodes that only recompute what a change
actually affects. This gap is the central motivation for the integration.

## Documents

- [`research-convex-reactivity.md`](research-convex-reactivity.md) —
  convex-backend triggers, subscription/invalidation model
  (read-sets, `SubscriptionManager`, OCC validation), and candidate plug-in
  points for an incremental engine (index backfill, search index
  maintenance, subscription invalidation, OCC validation).
- [`research-convex-query-composition.md`](research-convex-query-composition.md) —
  how queries/UDFs are defined and executed today (`QueryOperator`,
  `QueryStream`, the V8/isolate UDF boundary), and where a Skip-authored
  composable primitive could plug into the query pipeline or UDF API
  surface.
- [`research-skip-engine.md`](research-skip-engine.md) — Skip's core
  incremental engine: the language/runtime split, reactive collections,
  mappers/reducers, and a concrete comparison of what this buys over
  ordinary database reactivity.
- [`research-skip-externals-adapter.md`](research-skip-externals-adapter.md) —
  Skip's externals/polling model for ingesting outside data, skipruntime-ts's
  public API shape, and a detailed teardown of the existing
  `billf/convex/adapter` branch (snapshot-based polling with reactive
  diffing — its concrete limitations set the bar for "a better
  integration").
- [`research-skip-client-v2.md`](research-skip-client-v2.md) —
  Track 1 construction spec resolving the externals-adapter gaps
  (bounded-query contract, scope/auth, failure matrix).
- [`research-delta-seam.md`](research-delta-seam.md) —
  ranked reactivity seams with OCC/persistence exclusion and
  `QueryPatched` sketch.
- [`research-native-operator-spec.md`](research-native-operator-spec.md) —
  Track 2 construction spec recommending composable
  `QueryOperator::Skip` with touch list and wire example.
- [`research-build-slices.md`](research-build-slices.md) —
  ordered testable build slices with done-criteria.
- [`research-sync-protocol-skip-mapping.md`](research-sync-protocol-skip-mapping.md) —
  sub-direction 1a wire→Skip mapping (lifecycle, versions, chunks,
  bundle-preserving no-diff writes, PoC vehicle, correctness bar).
- [`research-sync-wire-ts-checklist.md`](research-sync-wire-ts-checklist.md) —
  per-message/field/lifecycle checklist for the in-process TS
  `/api/sync` client (R1/R2/R5) plus unknowns.
- [`research-skip-atomic-write.md`](research-skip-atomic-write.md) —
  `isInit`/`native_eq` reconciliation, per-query fork/merge finding,
  missing batch primitive, no-diff rule, reducer bar (R2/R3/R4).
- [`research-poc-vehicle-and-harness.md`](research-poc-vehicle-and-harness.md) —
  PoC queries, aggregates, keying/encoding rules, R6 harness sketch
  (R4/R6/R7/R8).

## Status

Research only — no design decisions have been made yet. Next step is to
fold this in once the parallel Codex-drafted plan lands, then refine with
higher-quality models in bite-sized, serialized passes.

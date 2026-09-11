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

### Foundation (read first)

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

### Direction 1 — Skip as reactive client

Sub-direction 1a (direct sync-protocol client, no backend changes):

- [`research-sync-protocol-skip-mapping.md`](research-sync-protocol-skip-mapping.md) —
  sub-direction 1a wire→Skip mapping (lifecycle, versions, chunks,
  bundle-preserving no-diff writes, PoC vehicle, correctness bar).
- [`research-sync-wire-ts-checklist.md`](research-sync-wire-ts-checklist.md) —
  per-message/field/lifecycle checklist for the in-process TS
  `/api/sync` client (R1/R2/R5) plus unknowns.
- [`research-1a-review-answers.md`](research-1a-review-answers.md) —
  closes the four 1a review questions (QueryRemoved delete rule,
  chunk eligibility + reassemble-then-write, raw-client cost,
  R6 limits).
- [`research-skip-client-v2.md`](research-skip-client-v2.md) —
  Track 1 construction spec resolving the externals-adapter gaps
  (bounded-query contract, scope/auth, failure matrix).
  Transport recommendation superseded for 1a by the mapping doc above —
  contract/failure sections still hold.

Sub-direction 1b (paginated reactive source, no backend changes):

- [`research-1b-page-topology.md`](research-1b-page-topology.md) —
  paginated reactive source: pagination mechanics, per-page Skip
  regions with atomic split-swap options, disjointness/ordering,
  metrics without backend changes.
- [`research-spike-comparison.md`](research-spike-comparison.md) —
  unified N/K/F axes, shared counter/timer catalogs, per-spike
  baselines, comparator normalization, metric sources.
- [`research-skip-source-state.md`](research-skip-source-state.md) —
  combined Skip input shape, revision watermarks + GC, tombstones,
  ordering, restart-rebuild, fault-injection list (all spikes).

Sub-direction 1c (Data Sync push source, modest backend change):

- [`research-data-sync-source.md`](research-data-sync-source.md) —
  existing Data Sync contract reused by the push stream (snapshot/CDC,
  revisions/tombstones/truncations, opaque cursors + retention,
  selection, status, soft page limits, authz).
- [`research-push-stream-seam.md`](research-push-stream-seam.md) —
  push-stream seam: readable-timestamp wait with lost-wake protection,
  bounded SSE framing with disconnect-propagating cancellation,
  cursor-after-apply checkpointing with revision-watermark idempotency.

Shared Direction 1 inputs:

- [`research-poc-vehicle-and-harness.md`](research-poc-vehicle-and-harness.md) —
  PoC queries, aggregates, keying/encoding rules, R6 harness sketch
  (R4/R6/R7/R8).
- [`research-skip-atomic-write.md`](research-skip-atomic-write.md) —
  `isInit`/`native_eq` reconciliation, per-query fork/merge finding,
  missing batch primitive, no-diff rule, reducer bar (R2/R3/R4).

### Direction 2 — backend-native Skip cache

- [`research-backend-change-hook.md`](research-backend-change-hook.md) —
  committed-change hook comparison recommending `LogReader` tail with
  ts-grouped atomic apply, seed/rebuild paths, retention budget.
  (For external-source Direction 1c, superseded by the Data Sync
  contract above — retained for the backend-owned cache question.)
- [`research-index-id-metadata.md`](research-index-id-metadata.md) —
  stable-vs-internal index metadata split, lifecycle validation,
  `v.id` join edges with dangling-reference semantics.
- [`research-delta-seam.md`](research-delta-seam.md) —
  ranked reactivity seams with OCC/persistence exclusion and
  `QueryPatched` sketch. Early orientation; seam choice since settled
  per-direction by the hook note (Dir 2) and Data Sync note (1c).
- [`research-native-operator-spec.md`](research-native-operator-spec.md) —
  composable `QueryOperator::Skip` touch list and wire example.
  Predates the spike plans; one-shot-operator path explicitly rejected
  by the Direction 2 spike in favor of persistent maintenance.

### Sequencing (historical)

- [`research-build-slices.md`](research-build-slices.md) —
  ordered testable build slices with done-criteria. Predates the four
  spike plans in `docs/plans/`; kept for the slice-discipline template,
  not current scope.

## Status

Research only — no design decisions have been made yet. Four spike plans in
`docs/plans/` now own the active scope (1a sync-protocol client, 1b
paginated source, 1c Data Sync push source, Direction 2 materialized
cache); the index above marks which notes feed each plan and which early
notes are superseded or historical.

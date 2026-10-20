---
title: Build Slices (Ordered, Testable)
type: research-note
status: historical
direction: historical
date: 2026-09-10
---

# Build slices (ordered, testable)

Synthesis only. Turns the "future work" sections of the four original
foundation notes (`research-convex-reactivity.md`,
`research-convex-query-composition.md`, `research-skip-engine.md`,
`research-skip-externals-adapter.md`) plus the three construction specs
written immediately before it (`research-skip-client-v2.md`,
`research-delta-seam.md`, `research-native-operator-spec.md`) into build
order. Each slice states done-criteria; no slice modifies an existing
research note.

## Slices

1. T1-MVP (client-v2, no backend change). Typed resource + one bounded
   combined query + SSE to a single consumer + Convex/Skip divergence metric.
   Tests: adapter lifecycle (bootstrap/reject/resubscribe/shutdown) +
   service graph tests. Done: bounded-query contract held, lag metric
   recorded.
2. T1-scale. Partitioned subscriptions (one query per tenant/partition),
   backoff tuning, gateway auth in front of control port. Done: N partitions
   run independently; partition-key immutability enforced; control port
   unreachable directly.
3. Wire spike (`QueryPatched`, backend owners required). Flag-gated delta
   variant + fallback to snapshot; chunk path unchanged. Done: mixed-version
   interop demonstrated or deferral recorded with reason.
4. T2-spike (one `SkipFilter` end to end per operator spec). Single
   index-range → SkipFilter → limit pipeline over a bounded table. Done:
   TS→Rust round-trip, prefetch/limit interplay verified, fingerprint stable.
5. Index-cache generalization (per delta-seam seam 1). Skip-backed view
   behind `fast_forward_index_cache`; miss → re-query. Done: hit-rate + O(1)
   vs O(n) bench on an aggregate workload.

## Bench

Aggregate workload (e.g. per-key count/sum): measure per-write cost —
Skip `add`/`remove` O(1) vs full re-scan O(n) — plus end-to-end Convex→SSE
lag and Convex function-call volume per source write.

## Verify

- `ls research/skip-convex-integration/` shows 13 files at tip: 5 from 448410bc2 (README.md + 4 notes) plus 8 new files in 8d88c7eb1, which also modified README.md.
- Each new doc ends with an Acceptance section or an explicit gaps section: research-poc-vehicle-and-harness.md, research-skip-atomic-write.md, research-sync-wire-ts-checklist.md, and this doc record planning gaps/non-goals instead of Acceptance.

## Non-goals

Persistence layer, commit ordering / snapshot publication, query parsing and
planning, full Skip language toolchain in backend.

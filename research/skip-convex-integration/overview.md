---
title: Skip/Convex Integration Overview
type: research-overview
status: active
direction: foundation
date: 2026-09-11
---

# Skip/Convex Integration Overview

## Core Finding: The Reactivity Gap

**convex-backend's coarse invalidation model:**
When a write changes rows, Convex tracks read-sets to find overlapping queries, then invalidates and fully re-runs them. This is O(n). The entire query result recomputes, even if only one row changed.

**Skip's incremental computation model:**
Skip propagates changes through a memoized graph of operators (mappers, reducers, collections). A write calls `Reducer.add` or `.remove` on affected keys, and Skip recomputes only the nodes that depend on those keys. This is O(1) for most changes — the cost scales with the size of the change, not the size of the result.

This gap is why the Skip/Convex integration matters. Bridging these two models lets applications maintain complex derived state (joins, aggregates, ordered feeds, filtered views) with work that scales to the change rate, not the data size.

---

## Four Independent Spike Directions

Each spike tests one feasibility question about how to span this gap. They are orthogonal — passing or failing one does not affect the others.

### Direction 1a: Sync-Protocol Client
**Plan:** `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md`

Skip consumes live Convex data as a direct WebSocket client of the `/api/sync` protocol. Convex bundles all transaction-grouped query changes into one Transition, and one atomic Skip update writes each changed query's complete value (keyed by query ID, per the shared plan's P `SnapshotBatch`) without client-side diffing.

**Tests:** whether Skip's snapshot reconciliation and atomic update boundary can preserve transaction grouping end-to-end, and what the correctness harness looks like.

**Does not require:** Direction 1b's page topology, Direction 1c's document deltas, Direction 2's backend-native cache, or any backend changes.

### Direction 1b: Paginated Reactive Source  
**Plan:** `docs/plans/2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md`

Convex's existing reactive pagination divides an index range into cursor-bounded pages. Skip preserves page identity as separate input regions instead of concatenating them. When a page changes, only that page republishes; unchanged pages stay out of Skip's reconciliation.

**Tests:** whether page-level granularity reduces steady-state update work compared to monolithic query snapshots, and quantifies the bootstrap/retention cost.

**Does not require:** Direction 1a's sync client, Direction 1c's backend changefeeds, Direction 2's materialized cache, or any backend changes.

### Direction 1c: Data Sync Push Source
**Plan:** `docs/plans/2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md`

Skip consumes native Convex Data Sync (CDC + snapshot) pushed over an SSE-framed stream, woken by repeatable-timestamp progress. This provides actual document revisions (not query results), grouped by transaction.

**Tests:** whether document-level deltas enable update work that scales with changed document count rather than affected query result size, and what the push-stream seam looks like.

**Does not require:** Direction 1a's client, Direction 1b's page topology, Direction 2's backend cache, or any backend changes beyond the SSE endpoint.

### Direction 2: Backend-Native Materialized Cache
**Plan:** `docs/plans/2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md`

Skip runs inside convex-backend and maintains one pre-registered cached view (the Shared proof-vehicle contract's room-scoped feed) by consuming committed row-level changes. Changes are applied incrementally to a retained operator graph, avoiding the full re-run on each invalidation.

**Tests:** whether persistent Skip state can achieve sub-linear update work inside the database, and what the architecture looks like for seam integration and correctness validation.

**Does not require:** Direction 1's external source spikes or any changes to the query protocol. Proceeds independently from all three 1a/1b/1c variants.

---

## General Approach

**Research:** This directory holds 20 research docs, each backed by an evidence dossier in `evidence/`, validated in a Phase 1 adequacy pass recorded in `gists-consolidated.json`. The six tool/model combinations named informally elsewhere in this project's history (Opencode+Muse, Claude+{Sonnet,Haiku}, Codex+{terra,luna,sol}) are an informal label, not a documented fact — git history shows 5 commits that each plausibly batch-added a group of docs, but no manifest or frontmatter field confirms which combination(s) produced which batch, and a single batch may reflect more than one combination. Treat the taxonomy as informally named and unverified (see Known Constraints and Unknowns below).

### Phase 1 validation results

Phase 1 validated all 20 docs: **12 PASS / 8 PARTIAL / 0 FAIL**. No research doc was found inadequate outright — every PARTIAL finding is a refinement (a citation to fix, a scope note to correct), not a reason the doc can't be relied on for its stated purpose.

The 8 PARTIAL docs and why (status as of the absolute-confidence fix pass — pins below already corrected in the docs):
- `research-convex-reactivity.md` — citation error (fixed: `reads.rs:187-191` + `writes_overlap_by_index` at `:233`); coverage otherwise adequate.
- `research-convex-query-composition.md` — file reference inaccurate (fixed: `queryStreamNext` in `async_syscall.rs`, consumption via `npm-packages/convex/src/server/impl/query_impl.ts`); the V8/isolate section is thinner than the query-composition section.
- `research-skip-externals-adapter.md` — branch-scoped to `billf/convex/adapter` (header added); paths/routes corrected (`examples/` top-level, `/v1/streams`, 387 lines).
- `research-spike-comparison.md` — the N/K/F framework itself is sound, per-spike mappings added (`:60-82`); cited only by the shared-prerequisites plan (`1159`), zero citations from the four target spike plans (see Measurement Framework below).
- `research-skip-source-state.md` — dual citation retained (`CollectionWriter.update:476-501` primary + `ServiceInstance.update:768-782`); cited only by the shared-prerequisites plan, no spike plan cites it.
- `research-poc-vehicle-and-harness.md` — two-table vehicle superseded by the Shared proof-vehicle contract (doc rewritten: contract summary up front, A1/A2 retired, keying/encoding + harness shape retained); only Direction 2 actually cites it despite a "shared" framing.
- `research-native-operator-spec.md` — `MAX_QUERY_OPERATORS` fixed to 256; wire example hedged as proposed shape (`Skip` in neither enum yet); lacks incremental-maintenance detail for `incremental-materialized-cache-incremental-maintained-operators` (D2 R3); doesn't address Direction 2's `incremental-materialized-cache-fallback-metrics` (D2 R12) through `incremental-materialized-cache-native-surface-unchanged` (D2 R16).
- `research-build-slices.md` — historical doc superseded by the spike plans (specs named explicitly in-doc); outdated file-count claims remain.

**Planning and spikes:** A higher-capability planning pass (Codex, serialized small steps) produces the four spike plans in `docs/plans/`, each narrowly scoped to one technical question. Each spike owns its own metrics, correctness harness, and scaling evidence. The spikes do not entangle; you can evaluate them independently and decide later which directions warrant implementation.

**No shared implementation phase:** Each spike is a proof of concept designed to be thrown away. If a spike succeeds, its concrete findings (the PoC code, metrics, discovered constraints) feed into a separate implementation effort with different architecture choices and risk profiles than the spike.

---

## Measurement Framework

`research-spike-comparison.md` is the canonical cross-cutting framework doc defining the three scaling axes each spike measures against: **N** (total scope the monolithic path re-touches), **K** (change size per transaction), and **F** (derived fan-out of K). It also defines a shared counter catalog, a shared timer catalog (`commit(ack) → readable → delivered → applied → published`), a baselines table, and metric sources available without backend changes.

In practice, the four spikes use this framework unevenly — same shape, different vocabulary:

| Plan | N | K | F | Explicit O() notation |
|---|---|---|---|---|
| 1a | none | none | none | No — correctness-only |
| 1b | total loaded rows / dataset size | target page size / affected-page counts | none (no join in this vehicle) | No |
| 1c | "total selected rows N" | "changed selected documents per transaction K" | "affected join fan-out F" | Yes — O(K), O(K+F), O(N) in `data-sync-push-scaling-by-n-k-f` (1c R16) |
| Direction 2 | total data size / total unrelated data size | implicit (single-row update held fixed) | affected dependency fan-out/neighborhood | No, same conceptual shape as 1c |

Only 1c literally uses the N/K/F symbols and Big-O notation. Direction 2 uses the same conceptual axes without symbols. 1b uses two axes only, since its proof vehicle has no cross-table join at the input boundary. 1a has zero scaling requirements by explicit Key Decision — its Key Decisions state that success is bounded semantic correctness, not performance, and that quantifying latency or resource overhead was chosen against.

`research-spike-comparison.md`'s Phase 1 PARTIAL verdict recorded an earlier state in which no spike plan cited it and it lacked explicit per-spike metric mappings. Direction 2 now cites it in its scaling decision and study unit, adopting the shared axes and counter catalog. The research note remains PARTIAL because those mappings are still incomplete across the four spikes; the earlier zero-citation claim is historical, not a current verdict. `docs/plans/README.md`'s citation-hygiene/real-gap table should be read in that historical context.

---

## Correctness Baseline

Every spike's correctness gate compares Skip's output against a separately-executed, ordinary Convex query at a settled checkpoint — never against Skip's own internal consistency. Each plan uses different words for the same structural claim:

- **1a:** "independent Convex reader"
- **1b:** "independent monolithic indexed Convex query" / "monolithic baseline" — "monolithic" specifically contrasts unpaginated vs. paginated, since 1b's whole point is page-level granularity
- **1c:** "independent native Convex query"
- **Direction 2:** "independent native Convex result" / "independent correctness oracle"

The concrete methodology behind this (from `research-skip-source-state.md`): a parallel-reader comparator, writes paused at settled checkpoints anchored on version timestamps, Skip's snapshot compared against the independent native query via normalized deep-equal, with counts and a full timer chain reported alongside the O(K) vs. O(N) curves from Measurement Framework above. The comparator is exercised against the shared fault-injection surface covered in Known Constraints and Unknowns below.

---

## Known Constraints and Unknowns

**No public multi-collection atomic write in Skip's TypeScript API.** All four independent spikes hit the same structural gap as an open planning question: Skip Runtime's current public API does not expose one atomic write spanning several external collections, only single-collection updates. This surfaces in every plan's Dependencies/Assumptions and Outstanding Questions sections (1a, 1b, 1c's requirements framing, and Direction 2), each proposing its own workaround (a single combined input domain, or a narrowly scoped multi-collection atomic-write capability) without a shared resolution. This is one structural gap in the shared vehicle, not four separate minor concerns. **Update 2026-09-23:** 1a, 1b, and 1c now adopt the shared plan's P (a single combined input domain) as a direct dependency; Direction 2 implements the native equivalent.

**Shared fault-injection surface.** `research-skip-source-state.md` defines a fault list all four plans independently instantiate subsets of: disconnect-before-checkpoint, cursor expiry/invalid/ahead, table replacement, oversized transactions, `QueryFailed` vs. `QueryRemoved`, slow-consumer/backlog exhaustion, mid-CDC restart, and page-split + invalid-cursor reset. **Update 2026-09-23:** the shared plan's Q6/Q7 now own these once; consumers supply only triggers, and query-state faults apply only to the query-subscription spikes (1a, 1b).

**Per-plan outstanding questions** (each plan's own Outstanding Questions section is the source of truth — these are signposts, not the full text):
- **1a** (~3 questions): which cross-table aggregate the demo computes; the demo's auth mode; single-domain vs. scoped-atomic-update choice for `sync-protocol-client-atomic-transition-apply` (1a R2).
- **1b** (~7 questions): page-size/dataset matrix; harness surface reuse; atomic multi-region representation for `paginated-reactive-source-atomic-page-split` (1b R4); internal metrics; deterministic failure injection; author-ID display choice; proceed/reject/narrow criteria.
- **1c** (~10 questions): route/event-envelope naming; per-page vs. periodic-status emission; progress visibility without forcing writes; a narrow wait API; buffering/cancellation limits; combined-input representation; watermark/tombstone idempotency; deterministic fault injection; scan-vs-emit metrics; N/K/F value selection.
- **Direction 2** (~8 questions): committed-change hook choice; index-metadata seam; schema representation for `v.id` joins; process lifetime; combined-domain vs. scoped-atomic choice for `incremental-materialized-cache-transaction-atomic-visibility` (D2 R2); rebuild/checkpoint/replay strategy for `incremental-materialized-cache-consistent-bootstrap-recovery` (D2 R6); logical-work counters; eager-vs-lazy base-view activation.

**Taxonomy caveat.** The tool/model attribution in General Approach above is a git-history reconstruction, not a documented fact — no manifest or frontmatter convention confirms which combination produced which doc batch. It could be upgraded from inferred to documented if such a convention is added later.

---

## Possible Future Extensions

- Add explicit per-spike metric-mapping citations to `research-spike-comparison.md` (tracked as a real-gap in `docs/plans/README.md`, not fixed here — that's a change to the spike plans, not this overview).
- If a spike is selected for implementation, this overview should gain a section linking to the implementation plan and noting which spike findings carried over.
- The reconstructed tool/model taxonomy (General Approach) could be upgraded from inferred to documented if a manifest or frontmatter convention is added later.

This overview is a starting point. The spike plans themselves are the source of truth for details, constraints, and scope boundaries.

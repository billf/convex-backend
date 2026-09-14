---
title: Skip Integration Spike Plans
type: plans-overlap
status: active
direction: n/a
date: 2026-09-11
---

# Skip Integration Spike Plans

This directory contains the four independent spike plans that explore Skip/Convex integration across two major directions. Each plan is deliberately scoped to answer one specific question about feasibility, scaling, or architectural boundary.

---

## Cross-Plan Overview

### Direction 1: Skip as External Reactive Source

Skip consumes live Convex data without backend changes (1a, 1b) or with modest backend changes (1c). Each variant tests a different granularity and delivery mechanism.

- **1a — Sync-Protocol Client (2026-09-10-1509):** Direct WebSocket client consuming transaction-grouped full query results. Tests whether Skip's snapshot reconciliation and atomic updates can preserve server-side state grouping without client-side row diffing.

- **1b — Paginated Reactive Source (2026-09-10-1843):** Convex query topology shaped into index-ordered pages that remain separate Skip input regions. Tests whether page-level granularity reduces update work compared to monolithic snapshots, and quantifies the bootstrap and subscription-state cost.

- **1c — Data Sync Push Source (2026-09-10-1854):** Server-pushed document revisions over an SSE-framed Data Sync stream, woken by native repeatable-timestamp progress. Tests whether actual document deltas (rather than query results) enable work that scales with changed document count rather than result size.

### Direction 2: Backend-Native Skip Materialized Cache

Skip runs inside convex-backend, consumes committed row-level changes, and serves versioned cached results alongside native query execution.

- **Direction 2 — Incremental Materialized Cache (2026-09-10-1702):** One pre-registered chatroom feed maintained by Skip's incremental engine from committed changes. Tests whether persistent Skip state can achieve sub-linear update work by applying changes to a retained operator graph rather than rerunning invalidated queries.

### How These Work Together

**Independence and isolation:**
- Direction 1 and Direction 2 are intentionally separate. The external source spikes (1a/1b/1c) do not depend on backend-native Skip and can be evaluated independently.
- Within Direction 1: 1a provides a baseline with full snapshots; 1b and 1c optimize different axes (query topology and document granularity). All three can proceed in parallel without blocking each other, **except that real implementation of any of 1a/1b/1c depends on the shared prerequisite tier (`docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`) landing first** — that plan's P (envelope convention) and Q (correctness-comparator harness) are the atomic-write and correctness-checking infrastructure all three otherwise independently defer to their own planning.

**Prerequisite tier:**
- `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md` sits beneath 1a/1b/1c/Direction 2. It is a shared build-once dependency for the external-source spikes (1a/1b/1c), not a fifth spike. See that plan's own scope notes on Direction 2, which is backend-native and does not consume the same external-adapter-shaped P/Q artifacts without further design work.

**Shared constraints:**
- All four plans share the same correctness bar: a Skip-maintained aggregate must match an independent native Convex result at settled checkpoints.
- All plans exercise Skip's incremental engine (mappers, reducers) rather than only relaying source data unchanged.
- All plans measure both the favorable scaling case and the costs (bootstrap, retained state, scan amplification, freshness) that accompany it.

**Evidence hierarchy:**
- Phase 1 research (20 docs, 12 pass / 8 partial) grounded the feasibility and architectural choices.
- These four spikes each own a narrow technical question: can we bound the implementation correctly, measure the scaling shape, and decide whether to generalize?
- A passing spike establishes bounded semantic feasibility; it does not make a generalization decision by itself.

---

## Research Coverage: Gaps and Citation Hygiene

Each spike plan cites research that directly supports its scope. This section identifies research docs that are relevant but omitted from each plan, and notes which docs are uncited globally.

**Classification:**
- **Citation-hygiene gap:** The research substance exists and is adequate, but the plan omits a citation. Typically fixed by adding a `Sources / Research` entry.
- **Real-gap:** The Phase 1 adequacy verdict flags missing content, insufficient depth, stale examples, or uncited design docs. Impacts the plan's evidence quality.

### Plan 1a (Sync-Protocol Client)

**Cites:** research-convex-reactivity.md, research-skip-engine.md, research-skip-externals-adapter.md, research-convex-query-composition.md, research-skip-atomic-write.md, research-sync-wire-ts-checklist.md, research-1a-review-answers.md, research-sync-protocol-skip-mapping.md, plus code references.

| Gap Doc | Reason | Type | Note |
|---------|--------|------|------|
| research-spike-comparison.md | Framework for cross-spike metric comparison; lacks per-1a mapping and uncited by 1a design. (PARTIAL) | Real-gap | Consider adding with caveat on per-spike instantiation |

### Plan 1b (Paginated Reactive Source)

**Cites:** 2026-09-10-1509-feat-skip-sync-protocol-client-plan.md (cross-plan ref), research-convex-reactivity.md, research-skip-engine.md, research-skip-atomic-write.md, research-1b-page-topology.md, plus npm/crates references.

No open gaps — hygiene entry resolved.

### Plan 1c (Data Sync Push Source)

**Cites:** crates files (streaming_export, table_iteration, database), research-convex-reactivity.md, research-skip-engine.md, research-delta-seam.md, research-backend-change-hook.md, research-data-sync-source.md, research-push-stream-seam.md, plus cross-plan refs.

No open gaps — hygiene entries resolved.

### Plan Direction 2 (Incremental Materialized Cache)

**Cites:** research-convex-reactivity.md, research-skip-engine.md, research-skip-externals-adapter.md, research-skip-atomic-write.md, research-poc-vehicle-and-harness.md, research-convex-query-composition.md, research-index-id-metadata.md, research-native-operator-spec.md, plus crates/npm references.

No open gaps — hygiene entries resolved.

### Globally Uncited (Not Referenced by Any Plan)

Research docs that exist in Phase 1 but are not cited by any of the four spike plans:

| Doc | Verdict | Direction | Reason for Omission |
|-----|---------|-----------|---------------------|
| research-skip-client-v2.md | PASS | 1 | Transport supersession; sections remain adequate despite not being specific to 1a/1b/1c choice. Could serve as 1b/1c fallback reference. |
| research-build-slices.md | PASS | historical | Historical scaffolding that framed earlier slice architecture; its content is subsumed by the four spike plans' more specific scopes. |

---

## Why These Gaps Don't Block the Spikes

**Citation-hygiene omissions** can be fixed by adding one-line `Sources / Research` entries. They do not alter the adequacy of the evidence or the spike's correctness strategy.

**Real-gaps** (e.g., research-spike-comparison.md lacking per-spike metric mappings) are noted in the Phase 1 summary but do not prevent the spikes from proceeding. Each spike defines its own metrics, and the consolidated gists' recommendation to cite research-spike-comparison.md with per-spike mapping is a follow-up refinement, not a blocker.

The two globally uncited docs (research-skip-client-v2.md, research-build-slices.md) are either superseded by the spikes' detailed requirements or represent historical scaffolding. Their Phase 1 pass verdict means their substance is accurate, so they remain available for reference without requiring incorporation into every plan.

---

## How to Read This Directory

1. **Start here:** Read this README to understand what each plan tests and how they relate.
2. **Pick a direction:** Read the plan file for the direction you're evaluating (1a, 1b, 1c, or Direction 2).
3. **Check constraints:** Each plan's "Scope Boundaries" and "Outstanding Questions" sections identify what is deliberately excluded or deferred to planning.
4. **Cross-reference:** Use the "How This Work Fits Together" section in each plan to understand which other plans share or diverge from its assumptions.
5. **Research depth:** Consult the research docs cited in "Sources / Research" for the detailed foundation. Use the gap table above to identify missing references if a claim seems undergrounded.

---

## Updating This README

As spikes progress:
- Update the `status` field to reflect completion, unblocking, or deferral.
- Add subsections under each plan summarizing planning decisions or discoveries if they affect cross-plan dependencies.
- If a plan branches into multiple sub-initiatives, document the new breakdown here with updated plan file references.

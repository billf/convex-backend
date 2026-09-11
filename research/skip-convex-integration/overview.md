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
When a write changes rows, Convex tracks read-sets to find overlapping queries, then invalidates and fully re-runs them. This is O(n) — the entire query result recomputes, even if only one row changed.

**Skip's incremental computation model:**
Skip propagates changes through a memoized graph of operators (mappers, reducers, collections). A write calls `Reducer.add` or `.remove` on affected keys, and Skip recomputes only the nodes that depend on those keys. This is O(1) for most changes — the cost scales with the size of the change, not the size of the result.

This gap is why the Skip/Convex integration matters: bridging these two models lets applications maintain complex derived state (joins, aggregates, ordered feeds, filtered views) with work that scales to the change rate, not the data size.

---

## Four Independent Spike Directions

Each spike tests one feasibility question about how to span this gap. They are orthogonal — passing or failing one does not affect the others.

### Direction 1a: Sync-Protocol Client
**Plan:** `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md`

Skip consumes live Convex data as a direct WebSocket client of the `/api/sync` protocol. Convex bundles all transaction-grouped query changes into one Transition, and Skip's `isInit: true` atomic update writes them without client-side diffing.

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

Skip runs inside convex-backend and maintains one pre-registered cached view (the chatroom feed from the tutorial) by consuming committed row-level changes. Changes are applied incrementally to a retained operator graph, avoiding the full re-run on each invalidation.

**Tests:** whether persistent Skip state can achieve sub-linear update work inside the database, and what the architecture looks like for seam integration and correctness validation.

**Does not require:** Direction 1's external source spikes or any changes to the query protocol. Proceeds independently from all three 1a/1b/1c variants.

---

## General Approach

**Research:** This directory holds 20 research docs gathered across multiple tool/model combinations (Opencode+Muse, Claude+{Sonnet,Haiku}, Codex+{terra,luna,sol}), validated in Phase 1 to confirm their adequacy. Phase 1 results: 14 docs PASS, 6 PARTIAL (technical details, some citations to fix). These research docs ground the architectural choices and feasibility assumptions in each spike.

**Planning and spikes:** A higher-capability planning pass (Codex, serialized small steps) produces the four spike plans in `docs/plans/`, each narrowly scoped to one technical question. Each spike owns its own metrics, correctness harness, and scaling evidence. The spikes do not entangle; you can evaluate them independently and decide later which directions warrant implementation.

**No shared implementation phase:** Each spike is a proof of concept designed to be thrown away. If a spike succeeds, its concrete findings (the PoC code, metrics, discovered constraints) feed into a separate implementation effort with different architecture choices and risk profiles than the spike.

---

## Next Steps

For another agent extending this overview:
- Expand "General Approach" with details on the research taxonomy and Phase 1 validation results
- Add a "Known Constraints and Unknowns" section summarizing outstanding questions from each plan
- Document the measurement framework and why all four spikes use the same metric axes (N = total rows, K = changed rows, F = join fan-out)
- Explain the correctness baseline: each spike compares against an independent native Convex query, not just internal consistency

This overview is a starting point. The spike plans themselves are the source of truth for details, constraints, and scope boundaries.

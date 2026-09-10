---
title: Skip Sync-Protocol Client - Plan
type: feat
date: 2026-09-10
topic: skip-sync-protocol-client
artifact_contract: ce-unified-plan/v1
artifact_readiness: requirements-only
product_contract_source: ce-brainstorm
execution: code
---

# Skip Sync-Protocol Client - Plan

## Goal Capsule

- **Objective:** Demonstrate that Skip can derive a correct, incrementally-computed, cross-table aggregate from convex-backend's live data — using a chatroom-style app — by consuming convex-backend's reactivity directly, with no backend changes and no client-side value diffing, establishing whether this integration path is worth generalizing.
- **Means:** An in-process TypeScript Skip external service that owns its own WebSocket to convex-backend's `/api/sync` protocol, writes each Convex transaction into Skip as one atomic update per query (`isInit: true`), and lets Skip's own reconciliation — not hand-rolled diffing — maintain the derived collections.
- **Product authority:** Settled by the user across two sessions (an interrupted prior session and this one). This plan owns sub-direction 1a only — see How This Work Fits Together for the surrounding, deliberately-separated directions that are not active scope.
- **Open blockers:** None — dialogue reached its exit conditions and every checkable claim in this plan was verified against source.

---

## Product Contract

### Summary

A proof-of-concept where a Skip sync client speaks convex-backend's sync WebSocket protocol directly, with no backend changes, treating each Convex transaction as one atomic write into Skip. A chatroom app combining a Skip example with the Convex tutorial demonstrates a cross-table aggregate computed correctly and incrementally — something the existing snapshot-diffing adapter branch cannot guarantee, because it receives Convex's per-query updates torn apart.

### Problem Frame

The only existing Skip+Convex integration is the `billf/convex/adapter` branch (in `~/src/skip`). It already avoids literal polling — it uses `ConvexClient.onUpdate`, a real push subscription — but it still runs through the JS `ConvexClient` and a Node-side `ExternalService` that diffs each new query snapshot against an in-memory copy of the previous one before feeding Skip. It also receives Convex's per-query updates one callback at a time, so a single Convex mutation that touches two tables can arrive at Skip as two separate, temporally torn updates.

convex-backend's own reactivity model is coarse — a changed query is fully re-run on invalidation, not incrementally recomputed — so the adapter's approach isn't an obviously wrong reading of what the client layer exposes. But the sync protocol underneath the JS client exposes more than the client surfaces: it bundles every query that changed in one Convex transaction into a single `Transition` message, and the protocol is not JS- or browser-specific. That structural fact is unused today and is the basis for this proof-of-concept.

### Key Decisions

- **Direct sync-protocol client, not a JS-client wrapper.** The Skip sync client owns its own WebSocket to `/api/sync` instead of going through `ConvexClient`, so it operates on whole `Transition` messages instead of per-query callbacks. (session-settled: user-directed — chosen over emulating reactivity through polling or a client-side shim, which was explicitly rejected from the outset.) Governs R1, R2.
- **Each Convex transaction is one atomic write into Skip.** Every query in one `Transition` is written to Skip together, so a cross-table derived value never observes a state where one table advanced and another didn't. Governs R2.
- **No hand-rolled value diffing.** The service writes each query's full current row set into Skip with `isInit: true` and lets Skip's own reconciliation compute what changed, rather than retaining a previous-snapshot map and diffing in TypeScript the way the adapter branch does. Governs R3.
- **In-process TypeScript, not an out-of-process Rust pump.** (session-settled: user-directed — chosen over a Rust process reusing convex-backend's existing Rust sync client: matches "prove first, generalize later"; the Rust route pays a real generalization cost this PoC doesn't need to pay yet.) Governs R1.
- **Success is correctness, not performance.** (session-settled: user-directed — chosen over also quantifying latency/overhead against the adapter branch.) Governs R6.
- **Failed queries freeze at last-good rather than going blank.** (session-settled: user-directed — chosen over blanking on `QueryFailed`, which is how the adapter branch behaves today: freezing is more graceful but requires the demo to be honest that a frozen value can be stale.) Governs R5.

### Requirements

**Sync-protocol client**
- R1. The Skip sync client subscribes to Convex queries by speaking the `/api/sync` WebSocket protocol directly, with no dependency on the JS `ConvexClient` and no changes to convex-backend itself.
- R2. Each `Transition` message the client receives is applied to Skip as a single atomic update spanning every query in that transition, not as independent per-query writes.

**Reconciliation**
- R3. Row-level adds, updates, and removals for a query are derived by writing that query's full current row set into Skip with `isInit: true` on each transition, not by the client computing a diff against a retained previous value.

**Skip-side computation**
- R4. At least one derived value is computed inside Skip via its reducer mechanism from data spanning more than one Convex query/table, so the demo evidences genuine incremental computation rather than a 1:1 relay of Convex data.

**Failure handling**
- R5. When a subscribed query enters a failed state, its previously-derived Skip view is retained (frozen at last-good) rather than cleared, and the demo surfaces that the value may be stale.

**Acceptance bar**
- R6. The demo's Skip-derived aggregate matches Convex's own data for the same point in time. No formal latency or resource-overhead comparison against the `billf/convex/adapter` branch is required.

**Proof vehicle**
- R7. The demonstration combines a Skip chatroom example from `~/src/skip/examples/*` with the Convex tutorial app (`~/src/convex-tutorial`).
- R8. The Convex side of the demo subscribes to plain per-table queries, not the tutorial's existing joined, `.take(50)`-limited query, so the cross-table join and the incremental count happen inside Skip rather than inside the Convex query.

<!-- ce-section: work-relationships -->
### How This Work Fits Together

This plan owns sub-direction 1a: a client-side-only, real-sync-protocol Skip integration with no convex-backend changes. It sits inside a broader, deliberately-separated set of Skip/convex-backend integration directions the user chose to keep apart rather than entangle. This is the current understanding, not a committed roadmap.

- Direction 1 — Skip as a reactive client/observable source of convex-backend
  - 1a — Client-side only, real sync protocol (this plan)
  - 1b — Fine-grained query architecture (shaping the Convex query set itself to approximate row-level deltas without backend changes) — Can proceed independently of 1a; Shares the same wire-protocol grounding
  - 1c — Modest backend changes to emit real row-level change events for external consumers — Enables a future 1a/1b to drop client-side reconciliation entirely; Still to decide whether it's worth building
- Direction 2 — Native Skip support inside convex-backend (triggers, composable queries/filters/mappers authored in Skip, exported via the convex-backend API) — Can proceed independently of Direction 1; a large distance separates it from Direction 1 by the user's own framing; Still to decide

### Actors

- A1. convex-backend — source of truth; commits mutations and emits `Transition` messages over `/api/sync`.
- A2. Skip sync client — the new component this plan builds; owns the WebSocket and applies transitions to Skip.
- A3. Skip runtime — computes the derived aggregate via its incremental engine.
- A4. Demo viewer — sees the aggregate update in the chatroom UI.

### Key Flows

- F1. Live cross-table aggregate update
  - **Trigger:** A user action causes a Convex mutation that touches two or more of the demo's subscribed tables in one transaction (e.g. posting a message and updating a per-room counter).
  - **Actors:** A1, A2, A3, A4
  - **Steps:** A1 commits the mutation and sends one `Transition` covering every changed query. A2 applies all of that transition's row-set writes to Skip atomically (`isInit: true` per query). A3's reducer recomputes the derived aggregate from the now-consistent state. A4 sees the updated aggregate.
  - **Outcome:** The aggregate reflects a state where both tables have advanced together; it never displays an intermediate state where only one has.
  - **Covers:** R2, R3, R4.
- F2. Query failure and recovery
  - **Trigger:** A subscribed query transitions to a failed state (e.g. a transient backend error).
  - **Actors:** A1, A2, A4
  - **Steps:** A1 sends a failed-query modification. A2 leaves the query's existing rows in Skip untouched rather than clearing them. A4 continues to see the last-good derived value, with a visible indicator that it may be stale. When the query recovers, A2 resumes writing fresh `isInit: true` row sets and the view un-freezes.
  - **Outcome:** The demo never goes blank on a transient failure, and the viewer is not misled into thinking a stale value is current.
  - **Covers:** R5.

### Acceptance Examples

- AE1. **Covers:** R2, R4.
  - **Given:** A chatroom demo subscribed to per-table queries, with a per-room message count computed in Skip via its reducer mechanism.
  - **When:** A single Convex mutation inserts a message and updates the room's activity field in one transaction.
  - **Then:** The Skip-derived count updates once, correctly; no intermediate render shows the message inserted without the count having incremented, or vice versa.
- AE2. **Covers:** R5.
  - **Given:** The demo is running and displaying a live per-room count.
  - **When:** The subscribed query underlying that count enters a failed state.
  - **Then:** The displayed count remains at its last-good value and the UI indicates it may be stale, until the query recovers.

### Scope Boundaries

**Deferred for later**
- Sub-direction 1b — shaping the Convex query set itself so today's per-query delivery approximates row-level deltas without backend changes.
- Sub-direction 1c — modest convex-backend changes to emit real row-level change events for external consumers.
- The simpler one-collection-per-query variant of this plan's approach (without the transaction-atomicity mechanism) — a legitimate lighter-weight alternative worth its own follow-up if the atomicity mechanism turns out to add more complexity than value in practice.
- An out-of-process Rust client reusing convex-backend's existing Rust sync client, for a future publishable or language-agnostic version.
- A quantified latency/resource-overhead comparison against the `billf/convex/adapter` branch.
- Durable delta replay across reconnects — a limitation of the underlying sync protocol itself (reconnection re-sends the query set and re-snapshots), not something this integration changes.

**Outside this product's identity**
- Direction 2 — convex-backend natively running Skip-authored logic (triggers, composable queries/filters/mappers) inside the backend itself. A separate, distant direction, not a later phase of this one.
- Rewriting convex-backend in Skip — rejected outright as too broad.

### Dependencies / Assumptions

- Assumes local checkouts of `~/src/skip` (for skipruntime-ts and the chatroom example) and `~/src/convex-tutorial` remain available and roughly in their current shape.
- Assumes a running convex-backend deployment to connect to. The auth mode for the demo's sync connection (e.g. an admin key vs. a real user token) has no product-facing consequence for a correctness-only PoC and is left to planning.
- A half-day de-risking spike is available before committing to owning the raw socket: `BaseConvexClient.addOnTransitionHandler` (still the JS client, not the deliverable) already exposes the full `Transition` with its timestamp, so the transaction-atomicity claim behind Key Decision 2 can be validated cheaply before R1/R2 are built against the raw protocol.

### Outstanding Questions

**Deferred to Planning**
- Which specific cross-table aggregate the demo computes (e.g. per-room message count vs. another candidate) — any real aggregate spanning more than one query satisfies R4.
- The demo's auth mode for its sync connection (see Dependencies / Assumptions).

### Sources / Research

- `research/skip-convex-integration/research-convex-reactivity.md` — convex-backend's subscription/invalidation model: coarse, full-query-rerun, not fine-grained incremental computation.
- `research/skip-convex-integration/research-skip-engine.md` — Skip's incremental engine internals (`EagerCollection`/`LazyCollection`, `Mapper`/`Reducer`).
- `research/skip-convex-integration/research-skip-externals-adapter.md` — Skip's externals model, skipruntime-ts's public API shape, and the `billf/convex/adapter` branch's design and limitations.
- `research/skip-convex-integration/research-convex-query-composition.md` — convex-backend's query/UDF execution model.
- `crates/convex/sync_types/src/types/mod.rs` — the wire contract: `StateModification` (`QueryUpdated`/`QueryFailed`/`QueryRemoved`, each carrying a query's full new value, not a row-level diff), `ServerMessage::Transition` (bundles all changed queries at one state version), `AuthenticationToken`.
- `crates/convex/src/client/` — the existing Rust sync client, confirming the protocol has no browser/JS-specific requirements.
- `~/src/skip`, `skiplang/prelude/src/skstore/EagerDir.sk` — the structural-equality (`native_eq`) short-circuit that makes `isInit: true` writes a free, exact diff.
- `~/src/skip`, `skipruntime-ts/skiplang/core/src/Runtime.sk` and `skipruntime-ts/core/src/index.ts` — `isInit` reset semantics and the `ExternalService.update` wiring.
- `~/src/skip`, `skipruntime-ts/adapters/convex/src/index.ts` on branch `billf/convex/adapter` — the baseline being improved on.
- `npm-packages/convex/src/browser/sync/client.ts` — `BaseConvexClient` and `addOnTransitionHandler`, the de-risking spike's entry point.

## Deferred / Open Questions

### From 2026-09-10 review

- **No instruction for handling removed queries** — Requirements (P2, scope-guardian, confidence 75)

  The plan names three wire-level change types the sync client must handle but writes requirements for only two, leaving no instruction for what happens when a subscribed query is removed by the server. This risks stale or orphaned rows lingering in Skip's derived state if the demo ever unsubscribes or resubscribes (e.g. switching rooms), undermining the correctness bar the plan is meant to guarantee.

- **Correctness-only bar doesn't test whether this integration is worth generalizing** — Goal Capsule / Requirements (P2, adversarial, confidence 75)

  Every requirement in the plan could be satisfied while its own stated goal — deciding whether this integration path is worth generalizing — stays unanswered. The one acceptance bar (R6, the correctness-only success bar) only tests one small demo shape and explicitly excludes performance, reconnects, and larger transactions, so a technically-passing demo may still leave the real decision resting on tacit judgment.

- **Atomicity guarantee doesn't account for chunked transitions** — Key Decisions / Sources and Research (P2, adversarial, confidence 75)

  The plan's atomic-per-transaction guarantee (R2, one atomic write into Skip per transaction) assumes the sync protocol always delivers a transaction as a single message. The protocol can fragment a large transaction across multiple chunks for certain client types, and the plan does not say whether the new client avoids or handles that case, so the atomicity guarantee is not actually assured as written.

- **De-risking spike validates only one narrow claim, not the load-bearing raw-client decision** — Dependencies / Assumptions (P2, adversarial, confidence 75)

  The plan's only pre-build validation step checks just one claim — that transactions arrive as a whole — rather than whether building and maintaining a from-scratch protocol client is tractable at all. The riskiest, hardest-to-reverse part of the plan (the decision to own a raw socket instead of the JS client) could only be found unworkable after most of the build is already done.

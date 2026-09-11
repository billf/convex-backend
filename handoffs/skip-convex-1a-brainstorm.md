---
artifact_contract: "ce-handoff/v1"
created_at: "2026-09-10T23:25:52Z"
title: "Skip/convex-backend integration — sub-direction 1a handoff"
summary: "Codex's interrupted ce-brainstorm on Skip+convex-backend was completed by another session for sub-direction 1a only; 1b, 1c, and Direction 2 remain unstarted."
keywords: ["skip", "convex-backend", "ce-brainstorm", "sync-protocol", "skiplabs", "incremental-computation"]
cwd: "/Users/bill/src/convex-backend"
resume_focus: "Decide whether to run ce-plan on the 1a requirements doc, or start a fresh ce-brainstorm for 1b, 1c, or Direction 2"
repository: "convex-backend"
repo_root_sha: "0780bbe665ae"
branch: "main"
head: "5202d8b8bdeb9152492554f89f63b2e2d7df46aa"
---

# Skip/convex-backend integration — handoff for Codex

## Why this exists

You (Codex) were running `compound-engineering:ce-brainstorm` on this exact topic in a separate session and stopped mid-flow after hitting your session usage limit — right as you were about to write plan(s) to disk (your last message was "I'll write the results to disk... using separate requirements-only plan artifacts"). A Claude Code session picked up from your interrupted grounding dossier and drove one scoped piece of the brainstorm to completion. This handoff hands that state back to you.

## Objective (the user's, established across both sessions)

Integrate Skip (skiplabs.io, an incremental-computation language/engine, local checkout `~/src/skip`) with convex-backend (this repo). Explicitly **not** "rewrite convex-backend in Skip" — the user rejected that framing as too broad early in your own session.

Two orthogonal top-level directions the user insists stay separate, each earning its own plan:

- **Direction 1** — Skip as a convex client / observable reactive source (consumed via skipruntime-ts), better than the existing `billf/convex/adapter` branch (in `~/src/skip`, not this repo).
- **Direction 2** — convex-backend natively supporting Skip (the language/engine) for triggers, composable queries/filters/mappers, exported via the convex-backend API — potentially living inside this repo. The user described "a very large distance" separating Direction 1 from Direction 2.

You had already reached this same framing before your session ended (see your own message: *"there's multiple directions we can take here... skip as a convex client... [very large distance separating]... convex supported using skip"*).

## What the other session did beyond where you stopped

Direction 1 turned out to have its own internal split, surfaced when the user was asked to scope down further (a `ce-brainstorm` coherent-work-gate requirement — one brainstorm run can only own one coherent piece of work):

- **1a — Client-side only, real sync protocol, no convex-backend changes.** Brainstormed and written up (see below). **This is the only piece with a finished requirements document.**
- **1b — Fine-grained query architecture** (shaping the Convex query set itself — e.g. small/keyed point-queries — so today's per-query update delivery approximates row-level deltas, still no backend changes). **Not started.** No brainstorm has run for this yet.
- **1c — Modest backend changes** to make convex-backend emit real document/row-level change events for external reactive consumers, without running Skip-authored logic inside the backend (that stays Direction 2's territory). **Not started.**

The user picked 1a first, explicitly calling it foundational ("the other two build on understanding this baseline") and asked that 1b and 1c be preserved as named, deferred candidates rather than folded into 1a's scope.

## Current state, in order of maturity

1. **Research — substantial, committed.** `research/skip-convex-integration/` on `main` (commits `805704477` through at least `b42e631fa`; not pushed to `origin`; the user plans to fork this repo eventually and asked explicitly not to push in the meantime). Contains both initial research documents plus expansions and construction specs added by an automated research agent ("muse"). Contents:
   - `README.md` — index and the core finding (see below).
   - `research-convex-reactivity.md` — convex-backend's subscription/invalidation model is **coarse**: read-set overlap triggers a full query re-run, not fine-grained incremental recomputation. Covers `SubscriptionManager`, OCC validation, and the sync-engine subscription seam (`ApplicationApi::subscription_client`, `SubscriptionTrait`, `crates/sync/src/worker.rs`).
   - `research-convex-query-composition.md` — the query/UDF execution model (`QueryOperator` enum, `QueryStream` trait, the V8 isolate boundary).
   - `research-skip-engine.md` — Skip's incremental engine internals: `EagerCollection`/`LazyCollection`, `Mapper`/`Reducer`, and why `Reducer.add`/`.remove` gives O(1) incremental aggregation vs. O(n) full recomputation.
   - `research-skip-externals-adapter.md` — Skip's externals/polling model, skipruntime-ts's public API shape, and a teardown of the `billf/convex/adapter` branch's snapshot-diffing design and its concrete limitations.
   - `research-skip-client-v2.md` — Track 1 construction spec resolving adapter gaps (bounded-query contract, scope/auth, failure matrix); includes an addendum noting that sub-direction 1a mandates the sync-protocol choice over the recommendations in the base spec.
   - `research-sync-protocol-skip-mapping.md` — **Answers two of the four open questions in the 1a plan:** wire-to-Skip mapping, lifecycle, versions, chunks, bundle-preserving no-diff writes, PoC vehicle shape, and correctness bar. Recommends a sidecar bridge (separate process) over embedded client, with embedded as fallback.
   - `research-sync-wire-ts-checklist.md` — Per-message/field/lifecycle checklist for an in-process TS `/api/sync` client (R1/R2/R5); validates the wire protocol shape and chunk-reassembly requirements (addressing one of the deferred questions).
   - `research-skip-atomic-write.md` — Deep dive on `isInit`/`native_eq` reconciliation, the per-query fork/merge finding, and the missing batch primitive that R2 needs.
   - `research-poc-vehicle-and-harness.md` — PoC queries, aggregates, keying/encoding rules, and R6 harness sketch (addresses R4/R6/R7/R8 planning details).
   - `research-build-slices.md` — Ordered, testable build slices with done-criteria; synthesis of research into a work order.
   - `research-delta-seam.md` — Ranked reactivity seams for backend-side integration (1c-adjacent thinking), OCC/persistence exclusion, and `QueryPatched` wire sketch (early Direction 2 architectural direction, not in scope for 1a).
   - `research-native-operator-spec.md` — Track 2 construction spec recommending composable `QueryOperator::Skip` with touch list and wire example (Direction 2 / 1c boundary, not in scope for 1a).

   **Core finding to keep central in every future plan on this initiative:** Skip's reactive dataflow engine does operator-level delta propagation with memoization; convex-backend's reactivity does not — it re-runs whole queries. This gap is the motivating reason for the entire initiative, and the user has repeated more than once that any plan must genuinely exercise it, not just relay Convex data through Skip untouched.

2. **1a requirements — done, reviewed, has open questions recorded.** `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md` (`artifact_contract: ce-unified-plan/v1`, `artifact_readiness: requirements-only`) — a `ce-brainstorm`-produced Product Contract, then pressure-tested with `ce-doc-review` (coherence, feasibility, product-lens, scope-guardian, adversarial personas; cross-model pass skipped at the user's request to avoid third-party egress).

   Shape of the plan: a Skip sync client speaks convex-backend's real `/api/sync` WebSocket protocol directly (`crates/convex/sync_types`) instead of going through the JS `ConvexClient` and the adapter branch's Node-side snapshot diffing. It writes each Convex transaction into Skip as **one atomic update** covering every query that changed (fixing a real correctness gap: the adapter branch's `ConvexClient.onUpdate` delivers per-query callbacks, so a transaction touching two tables can appear torn). Reconciliation relies on Skip's own `isInit: true` write path (which does a free, exact diff via structural-equality short-circuiting) rather than hand-rolled diffing. Proof vehicle: a chatroom demo combining a Skip example (`~/src/skip/examples/*`) with `~/src/convex-tutorial`, computing a real cross-table aggregate via Skip's reducer mechanism. Success bar is **correctness only** — no performance benchmark against the adapter branch required (a session-settled decision).

   The doc's own "How This Work Fits Together" section (marked `<!-- ce-section: work-relationships -->`) documents the 1a/1b/1c/Direction-2 relationship for a cold reader.

   **`ce-doc-review` added a "Deferred / Open Questions" section (dated 2026-09-10)** with four items. **Two have been addressed by the subsequent research:**
   
   *Answered by research:*
   - **QueryRemoved handling** — `research-sync-protocol-skip-mapping.md` (§2, row 7) specifies: drop last value + watermark on unsubscribe-completion.
   - **TransitionChunk fragmentation** — `research-sync-wire-ts-checklist.md` (§Lifecycle) documents: chunking is gated on `NPM && semver >= 1.28.0`; the new client can advertise support and implement reassembly, or advertise otherwise and accept up to 5MB messages. Also notes the Rust client explicitly refuses chunks, confirming client-type drives the decision.
   
   *Still open (planning-time):*
   - The correctness-only success bar doesn't by itself prove the plan's own stated goal (whether this path is worth generalizing) — every requirement could pass on this one small demo shape while reconnects, larger transactions, and multi-session behavior stay untested.
   - The plan's one pre-build de-risking spike (using the JS client's `BaseConvexClient.addOnTransitionHandler` to validate the atomicity claim cheaply) only validates that one claim, not the broader tractability of building and maintaining a from-scratch protocol client — the load-bearing, hardest-to-reverse decision in the plan.

   Also worth a look (FYI-tier, not blocking): product-lens flagged that the same `addOnTransitionHandler` hook the de-risking spike uses might already fix the adapter branch's stated defect on its own, which would mean the raw-socket rebuild (the plan's central mechanism) is justified mainly by future reusability rather than by the cited defect. Framed explicitly as advisory, not a claim the (session-settled) decision to build the raw client is wrong — worth a sanity check before or during the de-risking spike, not a blocker.
   
   **Generalization path:** The muse-generated `research-sync-protocol-skip-mapping.md` (§3) recommends a sidecar-bridge architecture (separate process owns the socket/client, passes batches to Skip) as the production generalization. It correctly identifies embedded client as the pragmatic PoC choice and sidecar as a valid follow-up refactoring once the PoC proves concept viability. No action required for 1a PoC; consider for planning or implementation if applicable.

3. **1b, 1c, Direction 2 — early research exists, no brainstorm yet.** While no formal brainstorm/planning has run for these sub-directions, the automated research agent has drafted early construction specs:
   - `research-native-operator-spec.md` — early Direction 2 exploration (composable `QueryOperator::Skip`, touch list, wire example). Not in 1a scope; reference for future Direction 2 brainstorm.
   - `research-delta-seam.md` — ranked backend reactivity seams for 1c-like architecture (index backfill, subscription invalidation, OCC validation) with exclusion rationale. Useful reference for future 1c scoping.
   - `research-build-slices.md` — synthesis of all research into a multi-track build order, mentioning 1a tracks (T1-MVP, T1-scale, T2-spike on SkipFilter end-to-end, index-cache generalization). Speculative but useful for understanding the dependencies across all three 1x sub-directions.

## Decisions and rejected alternatives (session-settled by the user; don't re-litigate)

- Real push/invalidation-driven reactivity only — no polling or snapshot-shim, rejected from the very start of your own session.
- 1a is scoped as client-side-only with **no convex-backend changes** — chosen over allowing "modest backend changes" (that's 1c) and over a "fine-grained query architecture" approach (that's 1b). The user explicitly asked for all three to be scoped as separate documents rather than picked between.
- Success shape for 1a: "prove first, generalize later" — build with quality as if publishable, but defer any actual publishing/generalization decision.
- In-process TypeScript client, not an out-of-process Rust process reusing convex-backend's existing Rust sync client — chosen to match "prove first, generalize later"; the Rust route was evaluated and found to pay real generalization costs (no `isInit`-equivalent reset on the external input-write API, transition granularity gets collapsed in the Rust crate's convenience layer) that this PoC doesn't need to pay yet.
- `QueryFailed` freezes the derived view at last-good rather than blanking it — chosen over blanking (which is how the adapter branch behaves today).
- Approach generation for 1a was elevated to Opus (native model override) rather than run on the session's default model, per the user's explicit request to spend frontier-model quality on plan-authorship steps specifically.

## Staffing/workflow preference the user has stated repeatedly

Two-tier model strategy for this initiative, and likely for similar future work: cheap, parallel Haiku-class fan-out for broad research/discovery (no cost concern there); actual plan authorship and refinement should run on high-quality frontier models (Opus on the Claude side; presumably your own highest-reasoning tier) but **serially**, on small bite-sized pieces, paced by subscription usage availability — not large parallel frontier-model subagent swarms. The user has said correctness and engineering quality outrank speed, and that taking a long time is fine.

## What happened after this handoff

Codex (resuming from the handoff) did **not** choose from the suggested next steps above. Instead, Codex started a fresh `ce-brainstorm` for Direction 2 and produced:

**`docs/plans/2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md`** — a requirements-only feasibility spike for backend-native Skip. The scope is one hand-crafted pre-registered chatroom materialized view, fed by committed Convex changes, with native query execution as the fallback. Key design decisions: maintain from commit-level changes (not invalidation-driven reruns), keep Skip state derived and rebuildable, use Convex indexes and validated IDs as lookup/join contracts, establish correctness and asymptotic scaling behavior before any performance microbenchmark.

This Direction 2 spike is **entirely independent of Direction 1a**. The sync-protocol client plan (`2026-09-10-1509-feat-skip-sync-protocol-client-plan.md`) remains a separate, viable work unit and can proceed without waiting on this spike's outcome.

## Plausible next steps after both plans are settled

- Run `ce-plan` on the 1a sync-protocol plan to enrich it into an implementation-ready execution plan.
- Run `ce-plan` on the Direction 2 spike plan to enrich it into an implementation-ready execution plan.
- Start a fresh `ce-brainstorm` for 1b (fine-grained query architecture) or 1c (backend row-level change events) — both still fully unscoped but with richer foundation material from the muse-generated research.

The two plans (1a and Direction 2 spike) establish viability and direction for their respective tracks. Neither blocks the other; the decision to pursue both, one, or neither is a user/product choice, not a technical dependency.

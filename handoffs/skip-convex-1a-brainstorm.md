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

1. **Research — done, committed.** `research/skip-convex-integration/` on `main` (commit `c547731f7` — not pushed to `origin`; the user plans to fork this repo eventually and asked explicitly not to push in the meantime). Contents:
   - `README.md` — index and the core finding (see below).
   - `research-convex-reactivity.md` — convex-backend's subscription/invalidation model is **coarse**: read-set overlap triggers a full query re-run, not fine-grained incremental recomputation. Covers `SubscriptionManager`, OCC validation, and the sync-engine subscription seam (`ApplicationApi::subscription_client`, `SubscriptionTrait`, `crates/sync/src/worker.rs`).
   - `research-convex-query-composition.md` — the query/UDF execution model (`QueryOperator` enum, `QueryStream` trait, the V8 isolate boundary).
   - `research-skip-engine.md` — Skip's incremental engine internals: `EagerCollection`/`LazyCollection`, `Mapper`/`Reducer`, and why `Reducer.add`/`.remove` gives O(1) incremental aggregation vs. O(n) full recomputation.
   - `research-skip-externals-adapter.md` — Skip's externals/polling model, skipruntime-ts's public API shape, and a teardown of the `billf/convex/adapter` branch's snapshot-diffing design and its concrete limitations.

   **Core finding to keep central in every future plan on this initiative:** Skip's reactive dataflow engine does operator-level delta propagation with memoization; convex-backend's reactivity does not — it re-runs whole queries. This gap is the motivating reason for the entire initiative, and the user has repeated more than once that any plan must genuinely exercise it, not just relay Convex data through Skip untouched.

2. **1a requirements — done, reviewed, has open questions recorded.** `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md` (`artifact_contract: ce-unified-plan/v1`, `artifact_readiness: requirements-only`) — a `ce-brainstorm`-produced Product Contract, then pressure-tested with `ce-doc-review` (coherence, feasibility, product-lens, scope-guardian, adversarial personas; cross-model pass skipped at the user's request to avoid third-party egress).

   Shape of the plan: a Skip sync client speaks convex-backend's real `/api/sync` WebSocket protocol directly (`crates/convex/sync_types`) instead of going through the JS `ConvexClient` and the adapter branch's Node-side snapshot diffing. It writes each Convex transaction into Skip as **one atomic update** covering every query that changed (fixing a real correctness gap: the adapter branch's `ConvexClient.onUpdate` delivers per-query callbacks, so a transaction touching two tables can appear torn). Reconciliation relies on Skip's own `isInit: true` write path (which does a free, exact diff via structural-equality short-circuiting) rather than hand-rolled diffing. Proof vehicle: a chatroom demo combining a Skip example (`~/src/skip/examples/*`) with `~/src/convex-tutorial`, computing a real cross-table aggregate via Skip's reducer mechanism. Success bar is **correctness only** — no performance benchmark against the adapter branch required (a session-settled decision).

   The doc's own "How This Work Fits Together" section (marked `<!-- ce-section: work-relationships -->`) documents the 1a/1b/1c/Direction-2 relationship for a cold reader.

   **`ce-doc-review` added a "Deferred / Open Questions" section (dated 2026-09-10)** with four items worth resolving before or during planning:
   - No instruction for what the client does when a subscribed query is removed by the server (`QueryRemoved` — the plan only handles `QueryUpdated`/`QueryFailed`).
   - The correctness-only success bar doesn't by itself prove the plan's own stated goal (whether this path is worth generalizing) — every requirement could pass on this one small demo shape while reconnects, larger transactions, and multi-session behavior stay untested.
   - The atomicity guarantee (one write per `Transition`) doesn't yet account for the protocol's `TransitionChunk` fragmentation, which the wire protocol uses for large transactions on certain client types — worth checking whether the new client's self-identified type/version is eligible for this at all before assuming it away.
   - The plan's one pre-build de-risking spike (using the JS client's `BaseConvexClient.addOnTransitionHandler` to validate the atomicity claim cheaply) only validates that one claim, not the broader tractability of building and maintaining a from-scratch protocol client — the load-bearing, hardest-to-reverse decision in the plan.

   Also worth a look (FYI-tier, not blocking): product-lens flagged that the same `addOnTransitionHandler` hook the de-risking spike uses might already fix the adapter branch's stated defect on its own, which would mean the raw-socket rebuild (the plan's central mechanism) is justified mainly by future reusability rather than by the cited defect. Framed explicitly as advisory, not a claim the (session-settled) decision to build the raw client is wrong — worth a sanity check before or during the de-risking spike, not a blocker.

3. **1b, 1c, Direction 2 — not started.** No brainstorm, no research beyond what's already captured in `research/skip-convex-integration/` (which is relevant background for all of them, not just 1a).

## Decisions and rejected alternatives (session-settled by the user; don't re-litigate)

- Real push/invalidation-driven reactivity only — no polling or snapshot-shim, rejected from the very start of your own session.
- 1a is scoped as client-side-only with **no convex-backend changes** — chosen over allowing "modest backend changes" (that's 1c) and over a "fine-grained query architecture" approach (that's 1b). The user explicitly asked for all three to be scoped as separate documents rather than picked between.
- Success shape for 1a: "prove first, generalize later" — build with quality as if publishable, but defer any actual publishing/generalization decision.
- In-process TypeScript client, not an out-of-process Rust process reusing convex-backend's existing Rust sync client — chosen to match "prove first, generalize later"; the Rust route was evaluated and found to pay real generalization costs (no `isInit`-equivalent reset on the external input-write API, transition granularity gets collapsed in the Rust crate's convenience layer) that this PoC doesn't need to pay yet.
- `QueryFailed` freezes the derived view at last-good rather than blanking it — chosen over blanking (which is how the adapter branch behaves today).
- Approach generation for 1a was elevated to Opus (native model override) rather than run on the session's default model, per the user's explicit request to spend frontier-model quality on plan-authorship steps specifically.

## Staffing/workflow preference the user has stated repeatedly

Two-tier model strategy for this initiative, and likely for similar future work: cheap, parallel Haiku-class fan-out for broad research/discovery (no cost concern there); actual plan authorship and refinement should run on high-quality frontier models (Opus on the Claude side; presumably your own highest-reasoning tier) but **serially**, on small bite-sized pieces, paced by subscription usage availability — not large parallel frontier-model subagent swarms. The user has said correctness and engineering quality outrank speed, and that taking a long time is fine.

## Plausible next steps (the user's or yours to choose between — these are alternatives, not a sequence)

- Run `ce-plan` on `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md` to enrich it into an implementation-ready plan (folding in the four open questions above).
- Start a fresh `ce-brainstorm` for 1b (fine-grained query architecture) or 1c (modest backend changes) — both still fully unscoped.
- Start a fresh `ce-brainstorm` for Direction 2 (native Skip support inside convex-backend) — entirely separate from Direction 1's sub-directions.

Nothing above is a directive; the handoff is status, not an instruction to act on any particular one.

---
title: Skip Incremental Materialized Cache Spike - STE Version
type: feat
date: 2026-09-16
topic: skip-incremental-materialized-cache-spike
source_plan: 2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md
---

# Skip Incremental Materialized Cache Spike

## Purpose

This document gives an STE version of the spike plan.

The source plan is authoritative.

If this document differs from the source plan, use the source plan.

Use the source plan for exact file lists, command text, and detailed evidence.

The spike tests one backend-owned Skip materialized cache.

The cache serves one pre-registered chatroom feed.

Convex remains the only source of truth.

The cache must use committed Convex changes.

The cache must never accept or acknowledge an authoritative write.

The spike runs only in the open-source local backend.

Every new path must need an explicit opt-in and a knob.

The normal Convex path must remain unchanged when the cache is off.

## Regeneration and Staleness

Regenerate this document after every change to the source plan.

Use the source plan as the only input authority.

Compare requirements, decisions, work units, verification, and completion rules after regeneration.

Do not preserve a companion statement that the source plan no longer supports.

Run the STE checker on this document after each regeneration.

Run a symmetry review against the source plan when meaning changes.

## Objective

Determine if Convex can give correct current reactive results with work that follows the affected dependency neighborhood.

Do not use full result size as the main update-work term.

Use native Convex query execution as the fallback path.

Judge correctness and freshness before speed.

Use scaling behavior as the performance result.

## Stop Rules

Stop the spike and write the report when any condition below occurs.

- The host cannot apply one commit batch atomically.
- The write-log tail cannot stay within retention at the smallest scale point.
- The descending room take-50 needs whole-room recomputation, and no bounded alternative exists in the public collection API of Skip.
- The U1 read-and-arm proof cannot establish the KTD7 invariant with shipped primitives.

Treat each stop as a spike result.

For a read-and-arm stop, record the failed interleaving in the U8 report.

The plan owner decides whether to descope version-gated reads or wait for an upstream atomic primitive.

Do not widen product scope after a stop.

When no stop occurs, finish U1 through U8.

Then run every verification gate and write the U8 verdict.

## Product Contract

### Incremental Maintenance

- R1. Consume ordered row changes only after a Convex transaction commits.
- R1. Do not use polling, client diffs, or post-rerun snapshots as input.
- R2. Treat all changes from one commit as one atomic batch.
- R3. Maintain joins, filters, grouped reductions, and ordering incrementally.
- R3. An unrelated row must not cause equivalent recomputation.
- R4. Count logical work at each maintained stage.

### Authority and Recovery

- R5. Convex stays the only source of truth.
- R6. Build and rebuild from a consistent Convex state.
- R6. Do not publish an incomplete or transaction-torn result.

### Proof Vehicle

- R7. Accelerate only the shared room-scoped chat feed.
- R7. Use its five tables: rooms, users, memberships, messages, and likes.
- R7. Preserve active membership, nullable sender, grouped like count, ordering, and the 50-message limit.
- R8. Declare the view before deployment.
- R8. Do not generate views from schemas, published code, or first reads.

### Read and Fallback

- R9. Keep ordinary Convex arguments and result values.
- R9. Define lossless value mappings or a safe admitted value subset.
- R9. Treat a missing field and `null` as different values.
- R9. Reject each excluded value with a stated reason.
- R9. Use the connection causal-sync watermark as the required version.
- R10. Wait until the view reaches the required version.
- R10. Reject each reserved consistency mode that the spike does not support.
- R11. Use the equivalent native query for every unavailable or unhealthy view.
- R11. Record the fallback reason.
- R12. Report acceleration, fallback, progress, rebuild, and mismatch metrics.

### Evaluation

- R13. Compare each accelerated result with an independent native result at one logical version.
- R13. Test bootstrap, writes, deletes, restart, lag, and recovery.
- R14. Compare with the strongest applicable native Convex design.
- R15. Vary total data and affected fan-out separately.
- R15. Report maintained state with update work.
- R16. Keep existing behavior unchanged when the operator disables acceleration.

### Indexes and Joins

- R17. Materialize only the five proof-vehicle tables.
- R17. Give each table `by_id` and `by_creation_time` base views.
- R18. Back each more lookup, range, or ordering with an enabled Convex index.
- R19. Validate required indexes before activation and after index changes.
- R20. Use declared `v.id("targetTable")` fields as forward join edges.
- R21. Preserve native behavior when an ID has no target document.
- R22. Use an enabled index for every reverse join.

## Main Technical Decisions

### KTD1: Run a Private Node Host.

Run Skip in a Node child process that the backend supervises.

Use a private Unix socket between Rust and the host.

Use `SKIP_HOST_DIR` to name the pre-built host package.

Use WASM by default.

Use the native addon only when `SKIP_HOST_PLATFORM=native` is set.

Do not use the untyped Skip C ABI from Rust.

Do not use a per-invocation isolate for a long-lived graph.

Bound host restarts with `SKIP_HOST_MAX_RESTARTS` and backoff.

After that bound, mark the view Unhealthy until backend restart.

The child has no public protocol or independent deployment.

Measure host failures with restart and fallback metrics.

### KTD2: Read the Published Write Log

Tail the published write log with `LogReader`.

Group kept entries by commit timestamp.

Keep the five data tables and the `_tables`, `_index`, and `_schemas` tables.

Send one zero-entry update for a commit with no kept data.

Do not decode `IndexKeyBytes`.

Do not use committer hooks, read-set overlap, snapshots, or subscription signals.

### KTD3: Use One Combined Input Collection

Key each combined input item by `"<table>/<id>"`.

Call `ServiceInstance.update` once for each commit batch.

Use `[key, []]` for deletes.

Reject a batch timestamp that does not increase.

Serialize `apply` and `read_many` on one queue per generation.

Never replay after host failure, apply failure, or retention loss.

Rebuild instead.

### KTD4: Seed Then Tail

Capture a repeatable snapshot at timestamp S.

Seed the five tables from that snapshot.

Tail the log from S plus one.

Use the log maximum timestamp after seed as the catch-up fence.

Serve only after the applied timestamp reaches that fence.

Discard the generation after restart, mismatch, ineligibility, or retention loss.

Re-seed after each discard.

Mark the view ineligible after the configured re-seed failure bound.

### KTD5: Validate Registration

Load one JSON declaration from `SKIP_CACHE_VIEW_FILE`.

The declaration names tables, indexes, join edges, and the accelerated query.

Validate indexes and `v.id` fields against the snapshot registries.

Tail registry changes in commit order.

Mark the view ineligible before serving a stale index or schema contract.

While ineligible, tail only registry tables.

Discard the generation while the view is ineligible.

Do not apply host batches while the view is ineligible.

Revalidate against a fresh snapshot after each relevant registry commit.

Resolve the five table IDs again before a new rebuild.

Start a new seed-and-tail generation only after validation succeeds.

### KTD6: Use Explicit Lifecycle States

Use Inactive, Rebuilding, Serving, Unhealthy, and Ineligible states.

Only Serving may return an accelerated result.

Give every fallback one enumerated reason.

Use `disabled`, `inactive`, `rebuilding`, `behind-deadline`, and `behind-cancelled`.

Use `view-version-expired`, `unhealthy-host`, and `unhealthy-apply`.

Use `ineligible-index`, `ineligible-schema`, `ineligible-retention`, and `known-incorrect`.

Invalidate subscriptions when the view leaves Serving.

Invalidate subscriptions when the host generation changes.

Keep `known-incorrect` as the rebuild reason until a good rebuild completes.

### KTD7: Pin a Read and Arm Its Notification

Use a view-backed subscription for accelerated reads.

The host must arm invalidation before it returns the first snapshot.

No apply or notification may be lost between the snapshot and that arm.

Prove this rule with shipped primitives.

If that proof fails, stop version-gated work.

Record the failed interleaving in the U8 report.

The plan owner decides whether to descope or wait for an upstream atomic primitive.

Use the actual host-read version for every query in one Transition.

Use native execution when that version is no longer readable.

### KTD8: Measure Logical Work

Count input rows, mapper calls, reducer calls, recomputes, and output changes.

Report host apply time and Rust queue time separately.

Report entry counts, live-resource count, and host RSS.

For a 100-times scale axis, classify a ratio at most two as neighborhood-bounded.

Classify a ratio of at least ten as total-data.

Call other ratios inconclusive.

Use the worst applicable counter for the classification.

Use unrelated-room values of 100, 1,000, and 10,000.

Use membership and like fan-out values of 1, 10, and 100.

### KTD9 and KTD10: Limit Test Scope

Do not depend on unavailable Rust test helpers.

Use self-contained Rust tests and local end-to-end tests.

Use the shared V1 through V6 semantic corpus.

Use the four Q12 comparison gates.

## Work Units

### U1: Build the Skip Host

Build `npm-packages/skip-host`.

Create the five table base views eagerly after seed.

Expose ten base-view collection counts in status.

Build the room feed with membership filtering, nullable sender, like reduction, and descending order.

Measure whether `take(50)` stays incremental.

Set a maximum live room-resource count for each generation.

Close or evict resources when the host reaches that bound.

Expose `seed`, `apply`, `read_many`, `status`, and `reset` on the socket.

Gate `debug_corrupt` with the debug knob.

Record the registry package tarball hash.

Run the installed-artifact smoke test before U1 continues.

The smoke test must initialize, update, read, and receive one notification.

If that test fails, block U1 until the documented `skargo` fallback works.

Test atomic batches, dangling IDs, reducer removal, zero batches, ordering, and resource bounds.

Test all read-and-arm interleavings.

Create more resources than the generation bound.

Then reset or evict resources and prove the live count stays bounded.

Report RSS for that test.

### U2: Build `skip_cache`

Create `crates/skip_cache`.

Load and validate the view declaration.

Supervise the host process and its health checks.

Use the existing Node discovery and child shutdown pattern.

Test valid and invalid index facts, schema facts, host failures, and shutdown.

### U3: Feed, Seed, and Lifecycle

Implement log tailing, snapshot seed, fencing, and lifecycle changes.

Regroup each commit into one host batch.

Rebuild after retention loss or host failure.

Discard the generation when registration validation fails.

While ineligible, tail only `_tables`, `_index`, and `_schemas`.

Do not run a generation or host apply in that state.

Revalidate after each relevant commit against a fresh snapshot.

Start a rebuild only after validation succeeds.

Count consecutive re-seed failures after retention loss.

After `SKIP_CACHE_MAX_RESEEDS`, mark the view `ineligible-retention`.

Test commit grouping, seed-and-tail boundaries, and ineligible registry changes.

### U4: Gate and Subscribe

Wait for the required version before an accelerated read.

Read and arm the host subscription as one proven operation.

Fall back for cancellation, deadline, error, unreadable version, or bad state.

Bind each subscription to its serving generation and room.

Invalidate it on the first later change to that room.

Invalidate it when the view leaves Serving or the generation changes.

Do not invalidate it for a change to another room.

Extend validity only when no room change follows the returned version.

Test each fallback reason and each generation change.

### U5: Integrate Sync

Add an optional acceleration field to the connect protocol.

Accelerate only the registered feed with its exact argument shape.

Build the required version from the connection causal-sync watermark.

Include mutation-response timestamps from the current session.

Include retained native-subscription invalidation timestamps for this update.

Use one actual view timestamp for all queries in a Transition.

Keep all non-opted-in clients unchanged.

### U6: Wire the Local Backend

Start the cache only when `SKIP_CACHE_ENABLED` is set.

Add status, compare, and debug admin routes.

Hide debug routes unless `SKIP_CACHE_DEBUG_ENDPOINTS` is set.

Report lifecycle state, versions, counters, and host platform.

### U7: Build the Proof Vehicle and Harness

Build the five-table application and the independent native oracle.

Run the oracle once with acceleration disabled.

Test value mappings before equality checks.

Test V1 through V6, atomic updates, dangling sender, rebuild, index changes, host death, retention, and mismatch recovery.

Record the four comparison gates before each equality claim.

### U8: Run the Scaling Study

Vary unrelated rooms with affected fan-out fixed.

Vary membership and like fan-out with unrelated rooms fixed.

Record update-only logical-work deltas.

Record seed, rebuild, maintained state, live resources, and RSS separately.

Compare both native baseline queries at every scale point.

Call an all-fallback run a failed run.

Write the report and the bounded viability verdict.

## Success Criteria

Match every accelerated result with the native result at the same logical version.

Show neighborhood-bounded update work for one join-and-reduction path.

Report maintained-state cost with the time-complexity result.

Use acceleration often enough to produce a steady-state scaling curve.

Do not pass a run that falls back for every relevant request.

Make every fallback, lag, rebuild, and mismatch attributable.

Materialize both base views for each of the five proof-vehicle tables.

Prove an incompatible index change cannot leave acceleration active.

Match native behavior for forward joins and reverse indexed joins.

Match native behavior when a referenced document is missing.

Pass the shared V1 through V6 corpus and its manifest version.

State whether the tested integration is viable and whether later generalization should continue.

## Required Evidence

The accelerated result must equal the native result at the same logical version.

Do not assert equality before all four Q12 gates pass.

The four gates record source application, result publication, oracle observation, and freshness disposition.

The harness must show one complete result for each multi-table transaction.

The harness must show native fallback during rebuild and host failure.

The harness must show that an index or schema change blocks stale acceleration.

The harness must show that a missing sender produces `null`, not a missing field.

The harness must show that no read-and-arm interleaving loses an update.

The scaling report must separate update work from seed and rebuild work.

The report must name every limiting cost.

Name it as a Node-host cost, re-seed cost, or Skip-engine cost.

## Verification Gates

Run Rust format and lint for U2 through U6.

Run Rust unit tests for `skip_cache`, `convex_sync_types`, and `sync`.

Build `local_backend` with `skip_cache`.

Run JavaScript format and lint for U1, U5, U7, and U8.

Run the Skip host tests.

Run browser sync protocol tests.

Build the two new JavaScript packages.

Run end-to-end correctness with acceleration and debug paths enabled.

Run the native regression with acceleration disabled.

Run the full scaling study.

## Out of Scope

Do not add a general view planner.

Do not add schema or code-publish view generation.

Do not add lazy or read-through materialization.

Do not add a public Skip query API or Skip UDF type.

Do not add effectful triggers or delivery guarantees.

Do not add authoritative Skip writes or write-through behavior.

Do not add Direction 1 integration or a public changefeed.

Do not use a fixed microbenchmark threshold for the decision.

## Completion Rules

When no stop rule occurs, complete U1 through U8 and all verification gates.

Address every success criterion in the U8 report.

Record positive, negative, or inconclusive evidence for each criterion.

Remove unused experimental paths and unguarded debug code.

Keep each client API, result shape, and default behavior unchanged without opt-in.

Keep every fallback attributable to a KTD6 reason.

Update the required plan graph documents when this plan changes.

Use [IDENTIFIER-MAP.md](IDENTIFIER-MAP.md) before an identifier leaves this document.

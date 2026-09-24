---
title: Skip Shared Prerequisites - STE Version
type: feat
date: 2026-09-23
topic: skip-shared-prerequisites
source_plan: 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
---

# Skip Shared Prerequisites

## Purpose

This document gives an STE version of the shared prerequisites plan.

The source plan is authoritative.

If this document differs from the source plan, use the source plan.

Use the source plan for exact file lists, command text, diagrams, and detailed evidence.

The plan builds two shared deliverables for the Skip and Convex spikes.

Deliverable P is the atomic source batch contract and its TypeScript helpers.

Deliverable Q is the correctness comparator and fault harness.

Spikes 1a, 1b, and 1c use P and Q as direct dependencies.

Direction 2 uses only the Q12 specification.

## Regeneration and Staleness

Regenerate this document after every change to the source plan.

Use the source plan as the only input authority.

Compare requirements, decisions, work units, verification, and completion rules after regeneration.

Do not keep a companion statement that the source plan no longer supports.

Run the STE checker on this document after each regeneration.

Run a symmetry review against the source plan when meaning changes.

## Objective

Build the atomic write convention and the correctness harness one time.

Let 1a, 1b, and 1c use them instead of building their own.

Make each deliverable reviewable without the code of any spike.

Make each deliverable useful even if no spike goes to production.

## Stop Rules

Stop and escalate when a spike scenario cannot pass through the P or Q interface.

Fix that problem in this plan as a P or Q defect.

Do not fix that problem inside the spike.

Stop when a unit needs a Skip runtime change, an FFI change, or a Convex backend change.

Stop when the corpus translation differs from `semantic-vectors-v1.md`.

In that case, the research document is correct.

## Product Contract

### Status of the Product Contract

The Product Contract has five approved corrections.

The fixture permits repeated likes for one message and one user, because V6 needs them.

Q2 owns the third comparison gate.

The Q14 observer watches `groupProbe` and the feed, and every consumer serves `groupProbe`.

AE1 claims only one atomic source write and a correct settled result.

Direction 2 uses the specification only.

### Why the Plan Exists

1a and 1b have the same two open problems.

The first problem is an atomic write across many tables into Skip.

The second problem is a comparator that checks Skip results against Convex.

1c designed its own solution to both problems first.

1c now uses P and Q instead.

Direction 2 cannot use TypeScript code, because its implementation is inside the backend.

Skip has no batch write primitive.

One `writer.update` call on one combined collection gives the atomic write.

The shipped `convex_reactive` example already uses this method.

No harness exists for these spikes today.

### Deliverable P

P1 defines a language-neutral `AtomicSourceBatch` specification.

The specification gives each direction its source version, group, order, delete form, and replay rule.

The published group must never show a torn state to a subscriber.

P2 defines two encodings that do not replace each other.

`SnapshotBatch` is for 1a and 1b.

It keys each complete result by query or page region.

The bridge does not calculate row differences.

`RevisionDeltaBatch` is for 1c and Direction 2.

It carries revisions, tombstones, replay rules, and cursor rules.

P3 requires one `writer.update` call for each consistency group.

A partial `isInit` update is not permitted.

P4, P5, and P9 are the revision delta extension.

P4 applies a revision only when its timestamp is newer than the kept value.

P5 defines when to keep and when to discard tombstones.

P9 adds staging generations, atomic promotion, and a pending ledger for each page.

P6 shows the helpers on the shared room feed.

P7 requires test suites that do not use any spike or Q.

P8 states that P needs no Skip runtime change.

The snapshot baseline is P1 to P3, P6 to P8, and the `SnapshotBatch` helpers.

1a and 1b wait only for the snapshot baseline.

1c also needs the revision delta extension.

### Deliverable Q

Q1 is a readiness detector for gates one and two.

Gate one means that the source applied its group.

Gate two means that Skip published the derived result.

Q1 supports quiesced checkpoints and checkpoints tagged with a revision.

Q1 does not read the oracle.

Q2 compares the Skip result with an independent native Convex read.

The default native reader is `ConvexClient` on the same deployment.

Q2 owns gate three.

Gate three means that the harness observed the native oracle.

A `convex-test` reader needs a passed parity check first.

A failed parity check is a harness error, not a Skip mismatch.

The SSE endpoints listen only on loopback.

Q3 normalizes both results and reports each key and field that differs.

Q4 drives the comparator with the versioned V1 to V6 corpus.

Q5 records counters and timers, and it owns gate four.

Gate four records the freshness state.

Q6 gives fault injectors in two tiers.

The snapshot tier covers disconnect, query failure states, multi-table transactions, and slow consumers.

The revision tier covers cursor faults, table replacement, oversized transactions, and restarts.

Q7 gives one assertion helper for detection, recovery, and counting.

Q8 proves that the comparator finds seeded mismatches.

Q9 runs Q from start to end with its own reference source.

Q10 gives a report format that spikes can cite.

Q11 makes the shared catalog the only source for metric names.

Q12 is a language-neutral specification of the method.

Q13 owns the five-table fixture in `convex-tutorial`.

Q14 is an observer that finds torn intermediate states.

### Shared Proof Vehicle

All four spikes use the same product.

The fixture has five tables: rooms, users, memberships, messages, and likes.

Each room and user pair has at most one membership.

Likes can repeat for one message and one user.

The canonical query selects messages in one room.

The sender of each message must have an active membership.

The query orders by `_creationTime` down, then `_id` down.

The query takes exactly 50 messages.

Each result has the message fields, the sender, and a like count.

The sender is null when the user does not exist.

The like count counts like rows.

## Main Technical Decisions

### KTD1: Package P in the Skip Workspace

Ship P as `@skip-adapter/atomic-batch` in `skipruntime-ts/adapters/atomic-batch/`.

Every TypeScript consumer is a Skip workspace.

A link across repositories is fragile, so the user chose this location.

Delay the upstream contribution until the provisional gate is clear.

### KTD2: Build Q as an In-Process Library

Ship Q as `skip-convex-proof-harness` in `examples/convex_proof_harness/`.

Consumers import its parts.

Q starts only the loopback reference service.

A comparator server would add a network boundary that no consumer needs.

### KTD3: Put the Fixture in the Tutorial

Put the Q13 fixture in `convex-tutorial` under the `proofVehicle` namespace.

Q calls the fixture functions by name.

Q does not import tutorial types.

The coupling is four items.

- The function names.
- The row shape of `allSelectedRows`.
- The corpus file.
- The loader command and its JSON output.

### KTD4: Use a Hand-Written Reference Source

The reference source subscribes to `allSelectedRows` through `ConvexClient`.

Each update becomes one `SnapshotBatch` under one query key.

Build each batch inside the transition handler.

Tag each batch with the timestamp of its transition.

Do not use `onUpdate` for this, because its timestamp can be one transition late.

The reference source sends harness mutations through the same client.

When a mutation resolves, the current timestamp is the required version for gate one.

A source on a different session cannot use the timestamps of the writer.

The public client does not expose the commit timestamp of a mutation.

That source also subscribes to the marker query.

After each write, the coordinator runs the marker mutation.

The marker acknowledgment gives a sequence number.

Gate one uses the first source transition that shows that sequence number or a higher one.

Skip sends nothing to a stream when a result does not change.

Q therefore exports a checkpoint emitter.

Every consumer calls the emitter after each source group.

The emitter sends a checkpoint event with the source version.

Gate two fires on the first checkpoint at or after the required version.

Two seeded variants split the V6 update into two writes.

One variant writes the membership first.

The other variant writes the likes first.

Each variant waits for the first event before the second write.

### KTD5: Load the Corpus Through Import

Translate the V1 to V6 corpus into `corpus/v1.json`.

Do not add rows.

The loader is the command `scripts/proof-vehicle-load.ts`.

The loader is not a Convex module.

The loader imports rooms and users first.

Then it imports memberships and messages.

Then it imports likes.

The import sets each `_creationTime` explicitly.

The loader binds each label to its imported ID.

For the V4 tie, the larger `_id` gets the label that sorts first.

After binding, a mutation corrects the body of each tied row.

Q keeps a copy of the corpus.

Q checks the copy with a semantic hash, not a byte comparison.

### KTD6: Define the Metric Catalog Once

Keep the catalog as one TypeScript constant and one JSON Schema.

The recorder rejects unknown metric names.

A missing required metric is a harness error.

### KTD7: Write a Small SSE Reader

Skip has no Node client for its SSE endpoints.

Write a small reader in Q.

The reader knows three event names: `init`, `update`, and `checkpoint`.

A heartbeat has no `id` line.

The reader refuses hosts that are not loopback.

The reader stops on an unknown event or bad data.

### KTD8: Keep the Tutorial Working

Change `messages` to the room, sender, and body shape.

`sendMessage` creates the default room when necessary.

`getMessages` returns an empty list when the room does not exist.

`getMessages` keeps a `user` field with the sender value.

Use a new deployment or clear old messages before the first push.

The loader stops when it finds an old message row.

The reset function runs only when the fixture variable is set.

## Assumptions

1a and 1b must use P and Q as Skip workspaces.

If they cannot, stop and plan the packaging again.

Build `@skipruntime/wasm` before any test that needs the Skip runtime.

That build needs the Skiplang toolchain.

If the build fails, stop and escalate.

Do not replace the runtime with a mock.

Do not use `runService`, because it listens on all interfaces.

It is not known if `convex-test` accepts an explicit `_creationTime`.

If it does not, prove the V4 tie on the deployment.

## Work Order

Build the snapshot baseline first.

The snapshot baseline is U1 to U12.

U11 comes last in the snapshot baseline.

The snapshot baseline releases 1a and 1b.

Build the revision tier next.

The revision tier is U13 to U15.

The revision tier releases the verification of 1c units U4 and U6.

U16 follows U12 and gates no tier.

## Work Units

### U1: Write the P Specification and Package

Write `SPEC.md`, `README.md`, and the package files.

Add a README section that tells a reviewer what to read.

Test that P imports only public `@skipruntime/core` symbols.

Test that P imports nothing from a spike or from Q.

### U2: Build the Snapshot Helpers

Build a keyed builder that rejects duplicate keys.

Write each batch with exactly one `writer.update` call.

Reject a partial `isInit` update.

Do not calculate row differences.

Build namespaced keys and the order key.

Build split mappers that route each row by its `table` tag.

Use the same split mapper for snapshot batches and revision batches.

Test that a batch across many tables makes one update.

Test that both encodings make the same table collections.

### U3: Build the Room Feed and the Group Probe

Build the room feed graph on P.

Filter by active membership.

Join the nullable sender.

Count likes with exact removal.

Keep the newest 50 messages.

Build `groupProbe` as a separate resource.

`groupProbe` gives the membership state and the like count for each message.

`groupProbe` reads before the membership filter.

Export `groupProbe` so every consumer can serve it.

Test deleted senders, membership changes, like removal, and the 50-row limit.

### U4: Build the Fixture Schema and Queries

Run `npx convex dev` one time before this unit.

Read the generated Convex guidelines.

Add the five tables and the four indexes.

Add the canonical oracle query.

Add the prefix query and the all rows query.

`allSelectedRows` returns rows tagged with their table.

Add the marker query.

Migrate `sendMessage` and `getMessages`.

Test the tutorial flow and the oracle rules.

### U5: Build the Mutations, Corpus, and Loader

Add each required mutation.

Each mutation returns the affected IDs and a marker.

Do not remove duplicate likes.

Write `corpus/v1.json`.

Record the golden parity hashes beside the corpus.

Build the loader command.

Build a `convex-test` loader and a mutation log.

Test that V6 gives a like count of 2 before the membership filter.

Test that a missing mutation makes the parity check fail.

### U6: Build the Comparator

Normalize both results.

Report each key and field that differs.

Load the corpus copy and check its semantic hash.

Do not add tolerance options.

Test each seeded mismatch.

### U7: Build Readiness, the Recorder, and the Checkpoint Emitter

Build the readiness predicate for gates one and two.

Build the recorder and the JSONL report.

Build the checkpoint emitter.

In quiesced mode, the coordinator holds writes until Q1 and Q2 report.

Test that readiness never fires too early.

Test that a step with no result change settles on its checkpoint.

Test that a source on a different session reaches gate one through the marker sequence.

### U8: Build the Readers and the Parity Function

Build the SSE reader.

Build the native reader on `ConvexClient`.

After gate two, read one time on a client with no standing subscription to that query.

A standing subscription returns a cached result.

Accept the sample only when its version is at or after the target.

Accept the sample only when no write started before the read returned.

Otherwise, label the sample as not comparable.

In revision mode, the coordinator pauses writes until the read returns.

Build the parity function as pure code.

The parity function must match the golden hashes.

### U9: Build the No-Torn Observer

Record every published state of the watched resource.

The caller gives the state before and the state after the group.

A torn state is equal to neither of them.

For V6, watch `groupProbe`.

The feed alone cannot show a torn state that changes membership first.

Refuse a group when a partial state matches its state before or its state after.

Refuse a consumer service that does not serve `groupProbe`.

Test both write orders.

### U10: Build the Snapshot Fault Tier

Build each injector with a trigger, an expected state, and a counter name.

Build helpers for detection, recovery, and counting.

Test the three query failure states.

### U11: Run the Snapshot Reference

Run the reference service on `initService`.

Serve the routes on `127.0.0.1` only.

Load each vector with the loader command.

After the loader stops, run the marker mutation.

Compare at each checkpoint.

Run each fault.

Record the SSE transcripts.

Write the report.

Test that V1 to V6 match.

Test that both seeded write orders show a torn state.

Test that each batch has the timestamp of its own transition.

### U12: Write the Report Schemas

Write the report schema and the mismatch schema.

Add the Q review section to the README.

Test that Q imports no spike package.

### U13: Build the Revision Delta Extension

Build the revision envelope.

Keep `ts` as a decimal string and compare it as a big integer.

Apply a revision only when it is newer.

Build tombstones, generations, promotion, and the pending ledger.

Test replay, failure between groups, and old generation events.

### U14: Build the Revision Fault Tier

Build injectors for cursor faults, table replacement, oversized transactions, and restarts.

Test each injector with a scripted mock.

1c U6 gives the real triggers.

### U15: Run the Revision Reference

Replay V6 as one revision group.

Watch `groupProbe` with the observer.

Test that one group shows no torn state.

Test that two groups show a torn state in both orders.

### U16: Write the Q12 Methodology

Write `METHODOLOGY.md` for Direction 2.

Describe the four gates.

Describe the normalization rules and the metric axes.

Describe the no-torn observation method.

This unit does not gate the snapshot tier or the revision tier.

## Verification Gates

Build `@skipruntime/wasm` before the runtime tests.

Run the P tests with `npm test -w @skip-adapter/atomic-batch`.

Run the Q tests with `npm test -w skip-convex-proof-harness`.

Run the fixture tests with `npm test` in `convex-tutorial`.

The fixture tests prove the V4 boundary only.

The snapshot reference run proves the V4 tie.

Start a new local deployment.

Set `PROOF_VEHICLE_FIXTURE` to 1 with `npx convex env set`.

Run `npm run reference:snapshot -w skip-convex-proof-harness`.

Run `npm run reference:revision -w skip-convex-proof-harness` after the revision tier.

The snapshot gate needs U1 to U12 and the snapshot reference run.

The revision gate needs U13 to U15 and the revision reference run.

## Out of Scope

Do not build the transport source of each spike.

Do not build the page split triggers of 1b.

Do not add a Skip batch write primitive.

Do not change the Convex backend.

Do not decide which spike goes to production.

Do not build a native code companion for Direction 2.

## Completion Rules

Every test scenario exists and passes.

Both reference runs pass on a new local deployment.

Each acceptance example and each flow has an owner unit.

No Skip runtime, FFI, or backend code changes.

The tutorial app still works.

The README files and the methodology state the standalone value.

P and Q stay provisional until a real consumer validates them.

The plan graph shows the shipped state.

Remove code from failed attempts.

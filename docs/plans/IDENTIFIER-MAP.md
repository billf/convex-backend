---
title: Cross-document identifier map for docs/plans
purpose: >
  Resolve numbered identifiers (R#, F#, AE#, KTD#, U#, P#, Q#) that are cited
  from a document other than the one that defines them, without depending on
  that numbering staying stable or on line numbers.
---

# Identifier map

## Why this file exists

Every plan in `docs/plans/` numbers its own requirements (`R#`), flows
(`F#`), acceptance examples (`AE#`), key technical decisions (`KTD#`),
implementation units (`U#`), and — for the shared-prerequisites plan — its
library deliverables (`P#`, `Q#`). Numbering is fine for identifiers that
never leave their own document: it's compact, and renumbering a purely local
list breaks nothing outside that file.

It stops being fine the moment another document cites the identifier by
number. `1a's R2`, `1c's KTD7`, `the shared-prerequisites plan's P9` are all
citations like that today (see `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`,
"How This Work Fits Together", and the sibling plans' own Dependencies
sections). If the cited document ever renumbers — splits a requirement,
inserts one, or reorders a list — every citing document goes stale silently,
because nothing forces the citing prose to be re-checked against the new
numbering.

This file is the single place that problem gets fixed: it gives every
**cross-document** numbered identifier a descriptive, hierarchical anchor
that means the same thing regardless of renumbering, plus a one-line
restatement of what it actually says so a reader (in this repo or another)
never has to open the source document just to know what "1c's KTD7" is.

## How to use this file

- **Citing an identifier that already has a row below:** use its descriptive
  anchor in cross-document prose (for example,
  `paginated-reactive-source-bounded-prefix-load`), not a local number such as
  `1a's R2`. The source document may continue to use its local numbers.
- **Defining a new identifier that is only ever going to be used inside its
  own document:** keep numbering it (`R12`, `F4`, ...). It does not need a
  row here. Descriptive anchors don't need an index entry; numbered ones do,
  precisely because their number alone doesn't survive a repo-wide grep or a
  renumbering.
- **Defining a new identifier that is expected to be cited from another
  document** (a shared library requirement, a cross-plan contract point):
  give it a descriptive, hierarchical anchor directly in the source document
  instead of a number (`shared-prereqs-p-single-fork-per-atomic-unit`, not a new
  `P10`). It then needs no entry here at all — the anchor is already
  self-describing and stable.
- **Anchor shape:** `{plan-slug}-{concept}` or, when it belongs to a named
  sub-group, `{plan-slug}-{group}-{concept}` (e.g.
  `shared-prereqs-p-single-fork-per-atomic-unit`,
  `data-sync-push-ktd-generation-fenced-ingestion`). Hierarchy goes coarse to
  fine, left to right — never `R1(a)(2)(b)`-style nested numbering.
- **When a sibling plan is revised:** re-check every row below sourced from
  it, the same way `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`
  already flags in its own Assumptions section (line ~225).

Plan-slug key (verified against each file's own `topic:` frontmatter and
`docs/plans/README.md`'s explicit 1a/1b/1c/Direction 2 labeling):
`shared-prereqs` = `2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`;
`sync-protocol-client` (1a) = `2026-09-10-1509-feat-skip-sync-protocol-client-plan.md`;
`incremental-materialized-cache` (Direction 2) = `2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md`;
`paginated-reactive-source` (1b) = `2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md`;
`data-sync-push` (1c) = `2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md`.

## Shared library deliverables — `shared-prereqs`, P (envelope/atomic-write library)

Every P identifier is cross-document by design, so all are listed.

| ID | Descriptive anchor | What it says |
|---|---|---|
| P1 | `shared-prereqs-p-envelope-type` | One documented envelope shape (`{ts, deleted, component, table, _id, _creationTime, doc}`) specified once, consumed identically by every producer. |
| P2 | `shared-prereqs-p-library-surface` | The reusable TS library's surface: envelope type, split-mapper helper, keying convention with uniqueness checks, order-key helper. |
| P3 | `shared-prereqs-p-single-fork-per-atomic-unit` | Enforces one `writer.update` call per atomic unit (Transition / revision-timestamp group / page-group swap) — never split per-table calls for data that must land atomically. |
| P4 | `shared-prereqs-p-revision-watermark-idempotency` | In-value revision-watermark idempotency (`apply iff entry.ts > retained_ts`); explicitly not Skip's own subscription/session-tick watermark. |
| P5 | `shared-prereqs-p-tombstone-gc-policy` | Tombstone/GC convention: retain while the generation lives, discard wholesale on resnapshot, sweep once past the retention horizon. |
| P6 | `shared-prereqs-p-poc-vehicle-demo` | Split/join/order helpers demonstrated against the frozen PoC vehicle (A1 reducer, A2 join). |
| P7 | `shared-prereqs-p-standalone-test-suite` | The library's own test suite covers split/merge/order/watermark/tombstone with no dependency on any spike's transport or on Q. |
| P8 | `shared-prereqs-p-no-runtime-change-required` | States no Skip runtime/FFI change is required; a batch primitive's absence is recorded as an out-of-scope future option. |
| P9 | `shared-prereqs-p-generation-fencing-extension` | **Optional** 1c-compatibility extension on the P1-P8 baseline: staging generation, atomic promotion, per-page pending ledger, generation-scoped watermarks, matching 1c's KTD7/KTD9 bar. Revised 2026-09-14 from mandatory baseline scope to optional — see `shared-prereqs`'s Outstanding Questions "P9 scope" entry. |

## Shared library deliverables — `shared-prereqs`, Q (comparator / fault-injection harness)

Every Q identifier is cross-document by design, so all are listed.

| ID | Descriptive anchor | What it says |
|---|---|---|
| Q1 | `shared-prereqs-q-settled-checkpoint-detector` | One reusable "is settled" predicate anchored on version timestamps. |
| Q2 | `shared-prereqs-q-dual-reader-wiring` | Compares a Skip-derived SSE snapshot against an independent native Convex reader, no shared code path; loopback-only, PoC/test-fixture data. |
| Q3 | `shared-prereqs-q-normalized-comparator` | Canonical-sort deep-equal comparator with the tutorial's "Unknown"-fallback parity rule; reports structured mismatches, not a bare boolean. |
| Q4 | `shared-prereqs-q-poc-vehicle-driver` | Driven against the frozen PoC vehicle's A1/A2 aggregates. |
| Q5 | `shared-prereqs-q-counter-timer-catalog` | Pluggable recorder implementing the shared counter/timer catalog from `research-spike-comparison.md`; a superset — 1a only populates Q1-Q3. |
| Q6 | `shared-prereqs-q-fault-injection-fixture` | Composable fault fixture covering the faults common to 3+ plans (disconnect-before-checkpoint, cursor expiry, table replacement, oversized transaction, etc). |
| Q7 | `shared-prereqs-q-fault-assertion-helper` | Each injector exposes a source-agnostic detect/recover/count assertion helper. |
| Q8 | `shared-prereqs-q-self-test-seeded-mismatches` | Harness's own suite proves the comparator catches a wrong Skip snapshot, via deliberately seeded mismatches. |
| Q9 | `shared-prereqs-q-runnable-reference-source` | Ships runnable end-to-end against the PoC vehicle with its own minimal reference source, before any of 1a/1b/1c/Direction 2 exists to consume it. |
| Q10 | `shared-prereqs-q-report-format` | Report format (counts/timers/mismatch log) directly consumable by any spike's Success Criteria without redefining metric names. |
| Q11 | `shared-prereqs-q-schema-matches-1c-jsonl` | Recorder field names/units match 1c's already-designed JSONL output (`data-sync-push-ktd-diagnostic-jsonl-schema`, KTD10) — Q generalizes 1c's U6 design rather than the reverse. |
| Q12 | `shared-prereqs-q-language-neutral-methodology-spec` | Settled-checkpoint definition, normalization rules, counter/timer names stated language-neutrally, so a non-TS consumer (Direction 2) can implement natively against the spec instead of the code. |

## `paginated-reactive-source` (1b)

Only identifiers actually cited from another document are listed; the rest of 1b's R1-R15/F1-F3/AE1-AE5 are local.

| ID | Descriptive anchor | What it says |
|---|---|---|
| R2 | `paginated-reactive-source-bounded-prefix-load` | Loads a configured, bounded prefix of the feed rather than materializing unbounded history. |
| R6 | `paginated-reactive-source-disjoint-page-merge` | Merges live page regions only after asserting disjoint Convex document-ID sets, then orders by indexed order with `_id` tiebreak. |
| R1 | `paginated-reactive-source-indexed-reactive-pagination` | Uses an enabled Convex index and reactive pagination to expose an ordered recent-message feed as cursor-bounded pages. |
| R3 | `paginated-reactive-source-stable-page-snapshot-region` | Gives each live page a stable identity and sends it to Skip as its own snapshot region without concatenating the loaded window or diffing rows in the bridge. |
| R4 | `paginated-reactive-source-atomic-page-split` | Keeps the old page active until both replacement ranges are complete, then exchanges old and new regions in one atomic Skip update. |
| R5 | `paginated-reactive-source-incomplete-split-result` | Treats a `SplitRequired` result as incomplete and never publishes it as a complete page range. |
| R7 | `paginated-reactive-source-loaded-window-reducer` | Maintains an aggregate over the loaded window with valid add and remove behavior. |
| R8 | `paginated-reactive-source-page-local-incremental-update` | Dirties only changed keys in the updated page and their dependent Skip nodes; unchanged pages are not republished. |
| R9 | `paginated-reactive-source-settled-monolithic-correctness` | Matches the paginated Skip feed and aggregate to an independent monolithic indexed query across lifecycle, split, reconnect, and failure-recovery scenarios. |
| R10 | `paginated-reactive-source-stale-window-rebuild` | Retains the last complete window as stale when a page fails or its cursor is invalid until a coherent page set is rebuilt. |
| R11 | `paginated-reactive-source-scaling-page-size-work` | Varies loaded rows and target page size while recording actual page sizes, affected pages, and observed update-work terms. |
| R12 | `paginated-reactive-source-page-work-instrumentation` | Counts and times page delivery, query-set changes, row and byte work, Skip dependency work, splits, rebuilds, and publication. |
| R13 | `paginated-reactive-source-monolithic-query-comparison` | Compares the paginated source with a monolithic indexed query for the same logical window, including steady-state and bootstrap/subscription trade-offs. |
| R14 | `paginated-reactive-source-no-full-republish-scaling` | Rejects runs that republish all loaded rows, omit page-split workloads, or report only elapsed time without logical-work counts. |
| R15 | `paginated-reactive-source-transition-grouped-client-scope` | Requires transition-grouped query updates in the client harness, but no raw 1a WebSocket client, backend protocol change, or backend-native Skip execution. |
| F1 | `paginated-reactive-source-steady-state-page-update` | A changed live page reaches Skip as a page-local snapshot, updates affected derived state, and leaves unchanged pages untouched. |
| F2 | `paginated-reactive-source-atomic-page-split` | A split loads complete replacement ranges, atomically swaps page regions, and then updates the merged feed. |
| F3 | `paginated-reactive-source-comparison-run` | A comparison run varies page topology and workload, records logical work, and verifies paginated and monolithic results at settled checkpoints. |

## `incremental-materialized-cache` (Direction 2)

| ID | Descriptive anchor | What it says |
|---|---|---|
| R4 | `incremental-materialized-cache-scaling-instrumentation` | Instruments logical work at each maintained stage so scaling behavior attributes to the changed dependency neighborhood. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| R9 | `incremental-materialized-cache-accelerated-handshake` | Ordinary Convex client handshake carries an experimental acceleration option; app query args/values stay ordinary Convex values. |
| R12 | `incremental-materialized-cache-fallback-metrics` | Metrics expose accelerated/fallback request counts, fallback rate and reason, view progress vs. required version, rebuild state, detected result mismatches. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| R13 | `incremental-materialized-cache-independent-correctness-check` | Correctness checked against an independent native Convex result across bootstrap/inserts/updates/deletes/multi-table/restart/lag/recovery. Cited by `shared-prereqs` as the spec-consumer target for Q12. |
| R15 | `incremental-materialized-cache-scaling-report` | Scaling report varies total data size and affected dependency fan-out, showing whether Skip update work and maintained state follow the expected complexity terms. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| AE7 | `incremental-materialized-cache-dangling-typed-reference` | "Dangling typed reference" acceptance example — the accelerated feed must match native missing-reference behavior. Cited by `shared-prereqs` alongside R13 as the Q12 spec-consumer target. |
| R1 | `incremental-materialized-cache-committed-row-change-input` | Consumes ordered row changes only after Convex commits; polling, post-rerun snapshots, and client-side diffs are invalid inputs. |
| R2 | `incremental-materialized-cache-transaction-atomic-visibility` | Makes all source changes from one Convex transaction visible atomically at one commit version. |
| R3 | `incremental-materialized-cache-incremental-maintained-operators` | Incrementally maintains joins, filters, grouped reductions, and ordering without equivalent recomputation for unrelated rows. |
| R6 | `incremental-materialized-cache-consistent-bootstrap-recovery` | Rebuilds from a consistent Convex state without publishing incomplete or transaction-torn accelerated results. |
| R7 | `incremental-materialized-cache-preregistered-room-message-feed` | Limits acceleration to a pre-registered room-scoped recent-message feed with validated-ID joins, membership filtering, like reduction, deterministic order, and bounded output. |
| R10 | `incremental-materialized-cache-required-version-consistency` | Waits until the view reaches the caller’s required commit version and rejects reserved unsupported consistency modes. |
| R11 | `incremental-materialized-cache-native-fallback` | Silently falls back to the equivalent native query when the accelerated view is unavailable, unhealthy, lagging, or known incorrect. |
| R14 | `incremental-materialized-cache-idiomatic-convex-baseline` | Compares against the strongest applicable idiomatic Convex baseline, including indexes, exact counters, aggregates, and denormalization. |
| R16 | `incremental-materialized-cache-native-surface-unchanged` | Keeps writes, UDFs, reactive behavior, result shapes, and client behavior unchanged when acceleration is disabled or bypassed. |
| R17 | `incremental-materialized-cache-implicit-base-index-views` | Materializes only the five proof tables with implicit Skip views corresponding to Convex’s built-in ID and creation-time indexes. |
| R18 | `incremental-materialized-cache-indexed-maintained-lookups` | Backs every additional Skip lookup, range, or ordering with its corresponding enabled Convex application index. |
| R19 | `incremental-materialized-cache-index-eligibility-validation` | Makes acceleration ineligible when required application indexes are missing, staged, disabled, removed, or incompatible. |
| R20 | `incremental-materialized-cache-validated-id-join-edges` | Derives pre-registered view join edges from validated `v.id("targetTable")` fields to target `by_id` materializations. |
| R21 | `incremental-materialized-cache-missing-target-join-semantics` | Preserves native behavior for missing referenced documents and does not treat `v.id` as referential integrity. |
| R22 | `incremental-materialized-cache-reverse-join-index` | Requires an enabled application index on the referencing ID field for reverse joins within the pre-registered view. |

## `data-sync-push` (1c)

| ID | Descriptive anchor | What it says |
|---|---|---|
| R8 | `data-sync-push-atomic-revision-group-apply` | Groups page values by exact Convex revision timestamp and applies every change from one transaction to Skip atomically before publishing. |
| R15 | `data-sync-push-comparison-harness-coverage` | Comparison harness covering bootstrap, CDC, reconnect (before/after apply), duplicate delivery, cancellation, table replacement, cursor expiry, process restart. |
| KTD1 | `data-sync-push-ktd-undocumented-sse-route` | Default-off undocumented POST route with native Axum SSE framing (`/api/data_sync_stream`), 404 while disabled. |
| KTD2 | `data-sync-push-ktd-preflight-before-200` | First-page preflight (auth, cursor validate, produce page) completes before HTTP 200; first page always emitted even if an unchanged empty page. |
| KTD3 | `data-sync-push-ktd-wait-past-readable-timestamp` | Narrow `Database` wait operation registers under the snapshot-manager lock and awaits after releasing it; no `SnapshotManager` exposure or timer-driven read. |
| KTD4 | `data-sync-push-ktd-bounded-producer-and-semaphore` | Capacity-one channel per producer, 64 MiB nominal queued-event budget, deployment-scoped 4-stream semaphore with HTTP 429 on saturation. |
| KTD5 | `data-sync-push-ktd-bounded-age-reauth` | Streams end at a bounded age (default 15 min) with heartbeats and a `reconnect` control event; narrowly scoped credential, redacted diagnostics. |
| KTD6 | `data-sync-push-ktd-lossless-timestamp-representation` | Version-1 `page` events encode revision `ts`/`snapshotTs` as canonical decimal strings; cursor stays in the event payload, not the SSE `id`. |
| KTD7 | `data-sync-push-ktd-generation-fenced-ingestion` | Models ingestion as a generation-fenced state machine via P: private candidate, first-consistent-page publish, replacement clone-and-promote, page-local replay ledger, generation rejection of late events. U4 imports P (P9) instead of hand-building this. |
| KTD8 | `data-sync-push-ktd-single-collection-tagged-keys` | Documents and control metadata share one Skip collection via tagged `(component, table, _id)` keys, so one `callbacks.update` call applies both tables and freshness state atomically. This is P's envelope/split-mapper convention (P1-P3). |
| KTD9 | `data-sync-push-ktd-scoped-replay-watermarks` | Replay watermarks and the pending-page ledger stay generation-scoped until the containing page cursor is recorded; process loss discards cursor and starts cold. This is P's watermark/tombstone convention (P4-P5), scoped per P9. |
| KTD10 | `data-sync-push-ktd-diagnostic-jsonl-schema` | Internal page statistics and per-page diagnostics exposed without expanding the public Data Sync contract; JSONL schema shares logical count names/units with 1b. Q11 generalizes this into Q's schema. |
| U4 | `data-sync-push-u-implement-push-service` | "Implement the Skip Data Sync push service" — imports P (or falls back to hand-building KTD7-KTD9 per the Goal Capsule's stop condition). |
| U5 | `data-sync-push-u-deterministic-tutorial-mutations` | "Add deterministic tutorial mutations and native oracles." |
| U6 | `data-sync-push-u-retained-graph-comparison-harness` | "Build the retained graph and comparison harness" — builds on Q (or falls back to a bespoke comparator/fault-injection core). |
| R2 | `data-sync-push-fixed-selection-cursor` | Opens with an optional opaque cursor and one fixed selection containing the tutorial’s `messages` and `users` columns. |
| R3 | `data-sync-push-progress-driven-page-emission` | Emits available pages without request round trips and wakes from repeatable progress beyond the prior page’s snapshot timestamp. |
| R4 | `data-sync-push-quiescent-empty-recheck` | Makes the wait path race-free and suppresses progress refresh for established unchanged empty `upToDate` rechecks. |
| R5 | `data-sync-push-bounded-stream-backpressure` | Bounds per-stream backlog and active streams, forcing slow consumers to resume from an applied cursor without unbounded memory or scan work. |
| R6 | `data-sync-push-staging-generation-activation` | Builds cold state in staging and publishes only a complete candidate at the first stale or current boundary. |
| R7 | `data-sync-push-atomic-table-replacement` | Applies truncations before values and atomically promotes a rebuilt replacement candidate while the prior view remains stale. |
| R9 | `data-sync-push-generation-scoped-replay-idempotency` | Records cursors only after successful timestamp groups and uses generation-scoped ledgers and watermarks for idempotent replay. |
| R10 | `data-sync-push-reconnect-and-cold-recovery` | Resumes reconnects from the last applied cursor while process loss or invalid cursors trigger fresh snapshots with stale last-good state when available. |
| R11 | `data-sync-push-terminal-error-freshness-safety` | Uses ordinary pre-event errors or terminal error events after headers, without advancing freshness or publishing partial candidates on failure. |
| R16 | `data-sync-push-scaling-by-n-k-f` | Varies selected size N, changed documents K, and join fan-out F to compare delta work with monolithic O(N) snapshots and retained O(N) state. |
| R17 | `data-sync-push-wake-and-work-counters` | Counts wake outcomes, suppressed refreshes, rechecks, pages, revisions, bytes, replay, cursor resets, Skip dependency work, publications, and stale intervals. |
| R18 | `data-sync-push-freshness-latency-timers` | Times readable progress, stream emission, atomic apply, derived publication, end-to-end freshness, snapshots, recovery, and stale duration. |

## `sync-protocol-client` (1a)

| ID | Descriptive anchor | What it says |
|---|---|---|
| R2 | `sync-protocol-client-atomic-transition-apply` | Each fully reassembled `Transition` applied to Skip as one atomic update spanning every included query modification. Cited by `shared-prereqs` as becoming "apply P's envelope convention to each reassembled Transition." |
| R4 | `sync-protocol-client-cross-query-reducer` | At least one derived value computed inside Skip's reducer from data spanning more than one Convex query/table (evidences genuine incremental computation). |
| R6 | `sync-protocol-client-settled-checkpoint-comparator` | At each controlled checkpoint the Skip-derived aggregate matches an independent Convex reader across bootstrap, multi-table update, unsubscribe, reconnect, and recovery. Cited by `shared-prereqs` as becoming "adopt Q's comparator and settled-checkpoint detector." |
| AE7 | `sync-protocol-client-first-attempt-failure` | "First-attempt failure" acceptance example. |
| R1 | `sync-protocol-client-direct-readonly-sync-client` | Implements the proof’s read-only `/api/sync` subset without JS `ConvexClient` or backend changes. |
| R3 | `sync-protocol-client-snapshot-reconciliation` | Sends each updated query’s complete row set to Skip for `isInit: true` reconciliation rather than bridge-side diffing. |
| R5 | `sync-protocol-client-last-good-failure-state` | Freezes a previously successful failed query with a stale indicator, or shows explicit not-yet-loaded state before first success. |
| R7 | `sync-protocol-client-chatroom-tutorial-proof` | Combines a Skip chatroom example with the Convex tutorial app as the demonstration vehicle. |
| R8 | `sync-protocol-client-per-table-query-proof-input` | Uses plain per-table subscriptions so Skip, not Convex, performs the cross-table join and incremental count. |
| R9 | `sync-protocol-client-unsubscribe-removal` | Removes `QueryRemoved` query rows inside the enclosing atomic update instead of retaining them as last-good state. |
| R11 | `sync-protocol-client-bounded-feasibility-record` | Records the implemented protocol surface, code/tests, and unexercised production concerns to bound the proof’s conclusion. |
| F1 | `sync-protocol-client-live-cross-table-aggregate` | Reassembles and atomically applies a transition, then updates and displays the cross-table aggregate without an intermediate state. |
| F2 | `sync-protocol-client-query-failure-recovery` | Retains a failed query’s last-good rows and stale value until recovery resumes fresh reconciliation. |
| AE1 | `sync-protocol-client-atomic-cross-table-update` | A transaction changing a message and room activity updates the Skip reducer once and matches the independent reader without an intermediate render. |
| AE2 | `sync-protocol-client-stale-last-good-on-failure` | A failed subscribed query leaves its displayed count at last-good with a stale indicator until recovery. |

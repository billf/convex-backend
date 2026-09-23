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

## Shared library deliverables — `shared-prereqs`, P (atomic-source-batch contract and external-source helpers)

Every P identifier is cross-document by design, so all are listed.

| ID | Descriptive anchor | What it says |
|---|---|---|
| P1 | `shared-prereqs-p-atomic-source-batch-contract` | Language-neutral batch mapping: source version/order, consistency group, delete/replay form, and no-torn publication for all four directions. |
| P2 | `shared-prereqs-p-snapshot-and-revision-encodings` | Non-interchangeable `SnapshotBatch` and `RevisionDeltaBatch` encodings; TS helpers are external-source-only while Direction 2 implements natively. |
| P3 | `shared-prereqs-p-external-single-fork-atomicity` | One external `writer.update` per external consistency group; snapshot paths use complete values and delta paths use tombstones, without prescribing Direction 2's native publisher. |
| P4 | `shared-prereqs-p-revision-delta-watermark-idempotency` | Revision-delta extension: watermark/tombstone replay safety; cursors advance after the full group succeeds. Direct dependency of 1c's U4; not carried by 1a/1b. |
| P5 | `shared-prereqs-p-tombstone-gc-policy` | Revision-delta extension: tombstone/GC convention — retain while the generation lives, discard wholesale on resnapshot, sweep once past the retention horizon. |
| P6 | `shared-prereqs-p-poc-vehicle-demo` | Split/join/order helpers demonstrated against the shared five-table room feed, including active membership, nullable sender, and `likeCount` add/remove behavior. |
| P7 | `shared-prereqs-p-standalone-test-suite` | Standalone test suites: the snapshot baseline covers reconciliation and split/merge/order; the revision-delta extension covers watermark/tombstone and generation fencing; neither depends on any spike's transport or on Q. |
| P8 | `shared-prereqs-p-no-runtime-change-required` | States no Skip runtime/FFI change is required; a batch primitive's absence is recorded as an out-of-scope future option. |
| P9 | `shared-prereqs-p-generation-fencing-extension` | Revision-delta extension (with P4-P5): staging generation, atomic promotion, per-page pending ledger, generation-scoped watermarks, matching 1c's KTD7/KTD9 bar. Revised 2026-09-14 from mandatory baseline to optional; 2026-09-23 required for 1c as a direct dependency, never part of the 1a/1b snapshot baseline — see `shared-prereqs`'s Outstanding Questions "P9 scope" entry. |

## Shared library deliverables — `shared-prereqs`, Q (comparator / fault-injection harness)

Every Q identifier is cross-document by design, so all are listed.

| ID | Descriptive anchor | What it says |
|---|---|---|
| Q1 | `shared-prereqs-q-settled-checkpoint-detector` | Readiness detector for source-applied and result-published gates, anchored on version timestamps. |
| Q2 | `shared-prereqs-q-dual-reader-wiring` | Compares a Skip-derived SSE snapshot against an independent native Convex reader, no shared code path; loopback-only, PoC/test-fixture data. |
| Q3 | `shared-prereqs-q-normalized-comparator` | Canonical-sort deep-equal comparator with nullable-sender and `likeCount` parity; reports structured mismatches, not a bare boolean. |
| Q4 | `shared-prereqs-q-poc-vehicle-driver` | Driven against the shared five-table room-feed proof vehicle, a versioned V1-V6 manifest, and exact canonical native oracle. |
| Q5 | `shared-prereqs-q-counter-timer-catalog` | Required/optional/N-A, direction-tagged recorder; owns freshness/fallback recording and preserves 1a's correctness-only exemption. |
| Q6 | `shared-prereqs-q-fault-injection-fixture` | Two-tier fault fixture: a snapshot-path baseline (disconnect-before-checkpoint, query-failure states, multi-table transaction, slow consumer) that 1a/1b gate on, and a revision-delta extension (cursor expiry, table replacement, oversized transaction, restart mid-CDC) required by 1c's U6. |
| Q7 | `shared-prereqs-q-fault-assertion-helper` | Each injector exposes a source-agnostic detect/recover/count assertion helper. |
| Q8 | `shared-prereqs-q-self-test-seeded-mismatches` | Harness's own suite proves the comparator catches a wrong Skip snapshot, via deliberately seeded mismatches. |
| Q9 | `shared-prereqs-q-runnable-reference-source` | Ships runnable end-to-end against Q13's proof-vehicle fixture with its own minimal reference source, before any of 1a/1b/1c/Direction 2 exists to consume it. |
| Q10 | `shared-prereqs-q-report-format` | Report format (counts/timers/mismatch log) directly consumable by any spike's Success Criteria without redefining metric names. |
| Q11 | `shared-prereqs-q-single-metric-schema-authority` | Recorder field names/units come from one authority — `research-spike-comparison.md`'s catalog with `research-core-metric-profile.md`'s mapping; 1c's KTD10 JSONL (`data-sync-push-ktd-diagnostic-jsonl-schema`) must be expressible in it. Renamed 2026-09-23 from `shared-prereqs-q-schema-matches-1c-jsonl`. |
| Q12 | `shared-prereqs-q-language-neutral-methodology-spec` | Four-gate checkpoint, runtime `current` vs harness-only `comparison-ready`, canonical equality, and metric profile stated language-neutrally for native consumers. |
| Q13 | `shared-prereqs-q-proof-vehicle-fixture` | Q owns the app-layer convex-tutorial fixture: five tables, required indexes, deterministic mutations, bounded native-oracle and per-table baseline queries, V1-V6 corpus loader. 1c's U5 consumes it; Q4/Q9 depend on it. Added 2026-09-23. |

## `paginated-reactive-source` (1b)

Only identifiers actually cited from another document are listed; the rest of 1b's R1-R15/F1-F3/AE1-AE6 are local.

| ID | Descriptive anchor | What it says |
|---|---|---|
| R2 | `paginated-reactive-source-bounded-prefix-load` | Loads a configured, bounded prefix of the feed rather than materializing unbounded history. |
| R6 | `paginated-reactive-source-disjoint-page-merge` | Merges live page regions only after asserting disjoint Convex document-ID sets, then produces the shared proof-vehicle contract's canonical ordering and projection. |
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
| R5 | `incremental-materialized-cache-authoritative-convex-source` | Convex remains the sole source of truth; the Skip subsystem cannot perform or acknowledge authoritative application writes. |
| R8 | `incremental-materialized-cache-preregistered-view-only` | The view is declared ahead of time as part of the experimental deployment; schema-driven generation, code-publish generation, and just-in-time construction are excluded. |
| AE1 | `incremental-materialized-cache-atomic-multi-table-update` | One Convex transaction changing membership plus a like moves the accelerated feed directly between complete versions with no observable partial state. |
| AE2 | `incremental-materialized-cache-version-gated-read` | A client requiring V2 while the view has published only V1 waits for V2 and receives a V2-or-newer accelerated result, never an older snapshot. |
| AE3 | `incremental-materialized-cache-silent-observable-fallback` | Rebuilding, unhealthy, or behind-deadline reads return the native Convex result while metrics count the fallback with its reason. |
| AE4 | `incremental-materialized-cache-scaling-demonstration` | Update work follows the affected dependency neighborhood on both the unrelated-data axis and the affected-fan-out axis against the native baseline. |
| AE5 | `incremental-materialized-cache-restart-without-stale-publication` | After process-local state loss, reads use native fallback until rebuild and catch-up complete, covering writes immediately before and after snapshot capture. |
| AE6 | `incremental-materialized-cache-index-lifecycle-gate` | A staged, removed, disabled, or incompatible required index makes acceleration ineligible before any stale-index result can be served. |
| AE8 | `incremental-materialized-cache-shared-semantic-corpus` | V1–V6 fixtures reaching comparison-ready checkpoints, including the descending 50th/51st boundary with `_id` tie-break and a common V6 final state. |
| KTD1 | `incremental-materialized-cache-ktd-node-child-host` | The Skip engine runs in a backend-supervised Node child process over a private Unix socket; direct Rust integration via the untyped C ABI is unsupported and out of scope, not nonexistent. |
| KTD2 | `incremental-materialized-cache-ktd-write-log-tail-feed` | The change feed is a tail of the published write log regrouped by commit timestamp, with zero-entry applies for commits with no kept entries. |
| KTD3 | `incremental-materialized-cache-ktd-combined-input-atomic-apply` | One combined Skip input collection is updated once per commit via `ServiceInstance.update`, with apply and read serialized per generation. |
| KTD4 | `incremental-materialized-cache-ktd-seed-then-tail-rebuild` | Rebuild is seed-then-tail with a catch-up fence and no persistence; any failure or retention loss discards the generation and re-seeds. |
| KTD5 | `incremental-materialized-cache-ktd-eligibility-validation` | Eligibility is validated against the snapshot registries at activation and re-validated from the same ordered tail, with a registry-only tail while ineligible. |
| KTD6 | `incremental-materialized-cache-ktd-lifecycle-states-fallback-reasons` | Inactive, Rebuilding, Serving, Unhealthy, and Ineligible states with an enumerated fallback reason on every non-accelerated read. |
| KTD7 | `incremental-materialized-cache-ktd-view-backed-version-pinned-reads` | View-backed subscriptions pin each Transition to the host read's captured timestamp, falling back natively on unreadable versions or deadline loss. |
| KTD8 | `incremental-materialized-cache-ktd-logical-work-counters` | Logical-work counters on both sides with shared names at fixed N/K/F points under a pre-registered largest-to-smallest ratio rule. |
| KTD9 | `incremental-materialized-cache-ktd-unit-plus-e2e-verification` | Pure-logic unit tests plus end-to-end local-backend runs, because this checkout carries no Rust integration fixtures. |
| KTD10 | `incremental-materialized-cache-ktd-admin-endpoints` | Spike-only local-backend admin endpoints for status, comparison, and debug lifecycle control behind knobs and admin auth. |
| U1 | `incremental-materialized-cache-u-skip-host-package` | Headless Node host maintaining the room-feed graph with base materializations, serialized apply and read, and per-batch work counters. |
| U2 | `incremental-materialized-cache-u-registration-host-supervision` | `skip_cache` crate loading and validating the pre-registered view declaration while supervising the Node host process. |
| U3 | `incremental-materialized-cache-u-feed-seed-lifecycle` | Write-log tail regrouping, consistent-snapshot seeding, and the lifecycle state machine with fence and retention handling. |
| U4 | `incremental-materialized-cache-u-version-gate-subscription-compare` | Version-gated reads, view-backed subscriptions, and same-version comparison against the native oracle. |
| U5 | `incremental-materialized-cache-u-sync-protocol-opt-in` | Connection-handshake acceleration opt-in with sync-worker feed substitution inside snapshot-consistent Transitions. |
| U6 | `incremental-materialized-cache-u-local-backend-wiring` | Local-backend construction, knobs, and admin-endpoint mounting for the cache client. |
| U7 | `incremental-materialized-cache-u-proof-vehicle-corpus-harness` | Independent oracle app, V1–V6 corpus, and correctness, fault, and lifecycle harness against the local backend. |
| U8 | `incremental-materialized-cache-u-scaling-study-verdict` | N/K/F scaling study with maintained-state costs and the spike viability verdict report. |

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
| KTD9 | `data-sync-push-ktd-scoped-replay-watermarks` | Replay watermarks and the pending-page ledger stay generation-scoped until the containing page cursor is recorded; process loss discards cursor and starts cold. Consumed from P's revision-delta extension (P4, P5, P9). |
| KTD10 | `data-sync-push-ktd-diagnostic-jsonl-schema` | Internal page statistics and per-page diagnostics exposed without expanding the public Data Sync contract; JSONL is produced by Q's recorder in Q11's single-authority schema, with direction-tagged 1c cursor extensions. |
| U4 | `data-sync-push-u-implement-push-service` | "Implement the Skip Data Sync push service" — imports P's snapshot baseline plus revision-delta extension; P gaps are escalated to `shared-prereqs`, with no hand-built fallback. |
| U5 | `data-sync-push-u-adopt-shared-proof-vehicle` | "Adopt the shared proof-vehicle fixture and add 1c proof support" — consumes Q13 and adds only 1c-specific timing/baseline support. Renamed 2026-09-23 from `data-sync-push-u-deterministic-tutorial-mutations`. |
| U6 | `data-sync-push-u-retained-graph-comparison-harness` | "Build the retained graph and comparison harness" — builds on Q (Q1-Q13, both Q6 tiers); Q gaps are escalated, with no bespoke fallback. |
| R2 | `data-sync-push-fixed-selection-cursor` | Opens with an optional opaque cursor and one fixed selection covering all columns of the `rooms`, `users`, `memberships`, `messages`, and `likes` tables. |
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
| R2 | `sync-protocol-client-atomic-transition-apply` | Each fully reassembled `Transition` is a complete `SnapshotBatch` applied atomically across every included query modification. |
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

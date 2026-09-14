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

- **Citing an identifier that already has a row below:** cite it either way
  (`1a's R2` or `paginated-reactive-source-bounded-prefix-load`), but prefer
  the descriptive anchor in new prose — it survives renumbering.
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
`docs/plans/README.md`'s explicit 1a/1b/1c/Direction 2 labeling — corrected
2026-09-14, see the note at the end of this file):
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

## `incremental-materialized-cache` (Direction 2)

| ID | Descriptive anchor | What it says |
|---|---|---|
| R4 | `incremental-materialized-cache-scaling-instrumentation` | Instruments logical work at each maintained stage so scaling behavior attributes to the changed dependency neighborhood. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| R9 | `incremental-materialized-cache-accelerated-handshake` | Ordinary Convex client handshake carries an experimental acceleration option; app query args/values stay ordinary Convex values. |
| R12 | `incremental-materialized-cache-fallback-metrics` | Metrics expose accelerated/fallback request counts, fallback rate and reason, view progress vs. required version, rebuild state, detected result mismatches. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| R13 | `incremental-materialized-cache-independent-correctness-check` | Correctness checked against an independent native Convex result across bootstrap/inserts/updates/deletes/multi-table/restart/lag/recovery. Cited by `shared-prereqs` as the spec-consumer target for Q12. |
| R15 | `incremental-materialized-cache-scaling-report` | Scaling report varies total data size and affected dependency fan-out, showing whether Skip update work and maintained state follow the expected complexity terms. Cited by `shared-prereqs` as needing Q12's counter/timer names. |
| AE7 | `incremental-materialized-cache-dangling-typed-reference` | "Dangling typed reference" acceptance example — the accelerated feed must match native missing-reference behavior. Cited by `shared-prereqs` alongside R13 as the Q12 spec-consumer target. |

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

## `sync-protocol-client` (1a)

| ID | Descriptive anchor | What it says |
|---|---|---|
| R2 | `sync-protocol-client-atomic-transition-apply` | Each fully reassembled `Transition` applied to Skip as one atomic update spanning every included query modification. Cited by `shared-prereqs` as becoming "apply P's envelope convention to each reassembled Transition." |
| R4 | `sync-protocol-client-cross-query-reducer` | At least one derived value computed inside Skip's reducer from data spanning more than one Convex query/table (evidences genuine incremental computation). |
| R6 | `sync-protocol-client-settled-checkpoint-comparator` | At each controlled checkpoint the Skip-derived aggregate matches an independent Convex reader across bootstrap, multi-table update, unsubscribe, reconnect, and recovery. Cited by `shared-prereqs` as becoming "adopt Q's comparator and settled-checkpoint detector." |
| AE7 | `sync-protocol-client-first-attempt-failure` | "First-attempt failure" acceptance example. |

**Resolved 2026-09-14: not a broken citation — this map's own plan-slug key
was wrong.** A prior version of this file attached the wrong (1a)/(1b)/
(Direction 2) alias to each file: it labeled `2026-09-10-1509-...` (actually
1a) as "(Direction 2)", `2026-09-10-1702-...` (actually Direction 2) as
"(1b)", and `2026-09-10-1843-...` (actually 1b) as "(1a)" — verified against
each file's own `topic:` frontmatter and `docs/plans/README.md`'s explicit
labeling. `shared-prereqs`'s citations of "Direction 2's R4/R12/R15/R13/AE7"
(lines ~93, ~183, ~274) were checked against the file *mislabeled*
"(Direction 2)" (`2026-09-10-1509-...`, which only goes to R11) instead of
the real Direction 2 file (`2026-09-10-1702-...`), which does define R12
("Metrics expose accelerated and fallback request counts..."), R13
("Correctness is checked against an independent native Convex result..."),
R15 ("The scaling report varies total data size and affected dependency
fan-out...") and AE7 ("Dangling typed reference") — confirmed by direct grep.
`shared-prereqs`'s citations were correct all along; this file's labels were
fixed instead (see the corrected plan-slug key and the three corrected
section headers above), and real rows for R12/R13/R15/AE7 live under
`incremental-materialized-cache` (Direction 2) above.

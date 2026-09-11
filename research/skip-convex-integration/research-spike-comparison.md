---
title: Spike Comparison Framework
type: research-note
status: active
direction: shared
date: 2026-09-11
---

# Spike comparison framework (1a / 1b / 1c / Direction 2)

Unified axes, counters, timers, baselines, and comparator rules so the four
spikes' scaling claims are stated in the same terms. Per-spike plans remain
authoritative for their own gates; this doc only aligns measurement.

## Unified axes

- `N` = total scope the monolithic path re-touches: 1c selected docs, 1b
  loaded rows (pages × actual length), Direction 2 dataset (unrelated
  rooms). Always report `O(N)` bootstrap + retained state alongside any
  steady-state win.
- `K` = change size per transaction: 1c selected revisions, 1b affected-page
  length (observed, never assumed `numItems`), Direction 2 changed rows in
  the dependency neighborhood. Steady-state delivery + Skip input must track
  `K`.
- `F` = derived fan-out of `K`: user→messages, message→likes, membership
  filter width. Derived update `O(K+F)`. 1b has no join-F; its analogue is
  changed-token count plus split-swap deletes/adds.
- 1a is correctness-only by session decision (no scaling axes): its
  contribution is the torn-delivery baseline and the atomicity mechanism the
  other spikes reuse.

## Shared counter catalog

Union of 1b-R12 / 1c-R17 / Direction-2 R4+R12: delivered rows/bytes; Skip
keys reconciled (added/changed/removed); dependent nodes updated; reducer
add/remove; splits/rebuilds (page splits, id-change rebuilds,
resnapshots); wake-ups by cause (native vs self-bookkeeping, heartbeats
excluded); replays/ignored (duplicates, cursor resets, InvalidCursor);
fallbacks by reason + rate; mismatches vs native.

## Shared timer catalog

`commit(ack) → readable(repeatable snapshot) → delivered(emission/receipt)
→ applied(Skip txn) → published(view)`, plus snapshot duration,
reconnect-recovery, and stale duration. 1a needs only
`Transition.endVersion.ts` anchoring; 1b needs publication; 1c and
Direction 2 need the full chain with logical-`Timestamp` vs wall-clock
separated. Empty wake-ups (timestamp advances for unrelated writes) and
unrelated-log scan work are counted, never presented as delivery.

## Baselines (hold equal at settled checkpoints)

| Spike | Baseline | Hold equal |
|---|---|---|
| 1a | `billf/convex/adapter` torn delivery | same writes; no torn intermediate; reducer correctness |
| 1b | monolithic indexed query, same prefix | same prefix + index; report bootstrap/live-query/page-state cost |
| 1c | monolithic snapshot `O(N)` | same N/K/F point; report `O(N)` bootstrap/retained + scan + readable-lag |
| Dir 2 | strongest idiomatic Convex (indexes, exact counts, counters, denormalization) | same feed semantics at same commit version; report fallback rate + lifecycle/index-gate costs |

## Comparator normalization

Anchor on `Transition.endVersion.ts` / DataSync `UpToDate(ts)` / required
version; snapshot the Skip resource per unit; gate staging (`snapshotting`)
vs current (`stale`/`upToDate`) so no partial candidate publishes. Sort
explicitly (Convex `order(desc).take(50).reverse()` vs Skip key order differ;
use `[creationTime,_id]` order key + `_id` tiebreak, never sort-at-read
only). Apply the tutorial `"Unknown"` fallback on both sides. Place `take(N)`
in Skip / bounded prefix only — never source-side `take` (reads as mass
deletion). Assert disjoint `_id` sets (never silent dedup); keep stable keys
(regenerated keys defeat `native_eq`); guard with `assertSkipJson`; separate
freeze-as-stale vs blank vs not-yet-loaded.

## Metric sources without backend changes

- `TxMetricsJson` (`async_syscall.rs:752-772` via explicit in-UDF call):
  `documentsRead/bytesRead` — not per-page automatic.
- Function warnings (`TooManyReads`, pagination-limit `logLines`) — limit/
  failure signals.
- `log_index_range` histograms (`metrics.rs:774-778`) — deployment
  aggregates, not per-page JS counts.
- Data Sync `TS_*` coverage counters (`data_sync.rs:147-152,440-911`) —
  test-only, zero-cost in prod; harness keeps its own page/revision/cursor
  counts.
- `Transition` timestamps / `maxObservedTimestamp`
  (`protocol.ts:225-264`, `client.ts:545-550`) — ordering + checkpoint
  anchor; causal watermark, not replay cursor.

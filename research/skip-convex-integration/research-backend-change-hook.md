---
title: Backend committed-change hook comparison
type: research-note
status: active
direction: 2
date: 2026-09-11
  - Retention parameters (30s/300s/50MB defaults)
  - Subscription tail pattern integration
  - IndexKeyWrites structure and ordering guarantees
verified_against_codebase: convex-backend crates/database/src
---

# Backend committed-change hook (Direction 2 R1/R2/R6)

Which internal seam feeds a backend-owned Skip cache with ordered,
atomic, rebuildable row changes. Compares five candidates; recommends one.

## Commit path (`database/src/committer.rs`)

`Committer::go` is the sole writer of log + snapshots. `next_commit_ts`
(`:1387-1399`) is strictly monotonic; `pending_writes` FIFO asserted at
`publish_commit` (`:973-987,1101`); `persistence_writes:FuturesOrdered`
(`:278,438-500`) publishes in `commit_ts` order. `publish_commit`
(`:1092-1139`) does `log.append` (`:1124`) then `snapshot_manager.push`
(`:1136`); the append-before-index-cache ordering is a proven 2PC
(`indexing/src/index_cache/mod.rs:434-460,519-534,556-601`).
`publish_max_repeatable_ts` (`:873-882`) advances `max_ts` with zero deltas —
followers must advance the cursor on empty ticks.

A direct `publish_commit` hook has full fidelity (full old/new docs,
index-key writes, snapshot) and exact order, but couples the cache to the
committer thread, `PendingWrites` lifetime, batch ordering, and snapshot
locks. Do not hook here; tail the published log instead.

## Write log (`database/src/write_log.rs`) — recommended

`WriteLog { by_database_index, by_text_index, max_ts, purged_ts }`
(`:546-551`). Records are `IndexKeyWrites` per `TabletIndexName`
(`:125-134`): `WriteInIndex { ts, index_updates, write_source }`
(`:427-431`), built by `index_keys_from_full_documents` (`:139-184`).
Each `DatabaseIndexWrite` carries `document_id`, old/new `IndexKeyBytes`,
and post-image `new_document` (`common/src/document_index_keys.rs:75-86`);
deletes are tombstone key + `new_document: None`; inserts have `old: None`.
Text writes carry no body; vector writes are absent from the log.
Only enabled indexes emit (`index_registry.rs:224-248,292-344`).
`WriteSource` (`:206-274`) distinguishes UDF/system writes.

Ordering: `append` asserts `max_ts < ts` (`:331-357`); per-index sets are
ts-ordered (`:458-478`) but cross-index merge is the caller's job
(`:718-742` takes the earliest `write_ts`). One commit fans out across many
index vectors — buffer `(from..=to]` and group by `WriteInIndex.ts` to
recover one atomic version. Resolve `TabletIndexName → table` at `end_ts`
(table create/drop/reuse needs live mapping).

Follow the proven tail pattern (`database/src/subscription.rs:320-353,
492-507`): `wait_for_higher_ts(processed_ts)` → `for_each_index
(processed_ts.succ(), next_ts)` (`write_log.rs:704-762`), apply, then
`processed_ts = next_ts`. The `fast_forward_index_cache` template
(`:768-820`) shows the replay-then-`None`-means-rebuild discipline.

Retention is the cliff: 30s min / 300s max / 50MB soft
(`common/src/knobs.rs:796-813`), trimmed to the slowest subscription manager
(`subscription.rs:229-254,649-656`). Misses surface as `OutOfRetention` /
`Err(None)` / `None` (`write_log.rs:585-604,608-624,736-743,792-794,831-832`).
Lag past the window means rebuild, not resume: seed from
`latest_ts_and_snapshot` / `latest_database_snapshot` (`database.rs:2025-2044`),
`begin_with_index_cache` (`:2002-2014`), or `document_deltas` /
`list_snapshot` (`:2133-2262,2265-2537`).

## Rejected candidates

- `Token`/read-set overlap (`token.rs:17-20`, `reads.rs:88-92,193-306`):
  invalidation signals, lossy for payload (keys + post-image only).
- `PendingWrites`: pre-commit, in-memory only, false conflicts.
- `SnapshotManager` diff: 10s window (`knobs.rs:407-410`), gaps from empty
  bumps, diff = scan.
- `subscribe` / `subscribe_and_wait_for_invalidation`
  (`database.rs:2086-2099`, `subscription.rs:492-660`): signal-only
  (`invalid_ts`), splay jitter (`:578-624`), UDF-source filtering — wakeup,
  not a row feed.

## Coupling risks

Lossy payload (post-image only, key-only deletes, enabled-only, no vectors);
per-index fan-out needs atomic regrouping incl. empty ticks; lag budget well
under retention MIN; registry evolution (enable/disable/drop, `_index`
virtual index) must mirror `fast_forward:779-787` invalidation; never reuse
the `subscribe` signal path or committer-thread hooks.

## Acceptance

Hook = `LogReader` tail with ts-grouped atomic apply; seed/rebuild paths
named; retention budget stated; lossy-payload limits recorded.

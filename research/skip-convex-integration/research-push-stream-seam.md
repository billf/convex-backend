---
title: Push-stream seam
type: research-note
status: active
direction: 1c
date: 2026-09-11
---

# Push-stream seam (Direction 1c/1d R3-R5)

How the caught-up stream waits without polling, frames output with bounded
backpressure, and checkpoints cursors idempotently. Builds on the Data Sync
contract (see `research-data-sync-source.md`); proposes no new capture model.

## Wait primitive: SnapshotManager, not timers

`snapshot_manager.rs:594-627`: `wait_for_higher_ts(target)` check-then-
register under one lock, future owns the `oneshot::Receiver`; `notify_
waiters` (`:594-606`) wakes `ts > waiter` and reaps closed senders. Same
template as the write-log waiter (`write_log.rs:313-378`). Precedent to copy:
`database.rs:1733-1742` `wait_for_write_ts` (pred-idom, no await under lock).

Wakers: every `push` (`:741-755`) — ordinary commits via
`publish_commit` (`committer.rs:1092-1139`) and max-repeatable bumps
(`:873-882`, post-commit 5s delay / 1-2h idle jitter,
`knobs.rs:604-619`). "Readable" = `latest_ts` (`database.rs:1728-1731`);
`latest_database_snapshot` (`:2029-2044`) is the page floor
(`application/src/streaming_export.rs:76-98`). Do not wait on
`persisted_max_repeatable_ts` for leader push. Narrow API: expose
`Database::wait_for_readable_ts` (+ application wrapper pairing page read
with wait-past-`snapshotTs`), never the snapshot manager itself.

Drain loop (R3/R4): `loop { page = data_sync(latest_snapshot);
emit while pages available; if UpToDate(ts) { wait_past(ts).await } }`.
`wait_past(ts)` = `wait_for_higher_ts(ts)` (`:599,614` semantics). Race-free
by check-then-register; cancel-safe via `select!` vs disconnect/shutdown
(precedent: `subscription.rs:321-353` `select_biased!`; do not copy the
weaker `function_log.rs:1720-1779` waiter). Heartbeats never trigger reads.

## Empty wake-ups

Any commit (even unrelated tables/maintenance) wakes all waiters; each empty
wake costs one `ts_page` scan (`data_sync.rs:611-760`: open repeatable
snapshot, scan `(synced_ts..=latest]`, classify captured vs skipped,
atomic timestamp cut) with zero emissions. Endpoint may advance its
in-memory cursor silently but must count it (R17/R18: native wake-ups vs
non-empty pages, rows examined vs emitted). `BY_ID_FRESHNESS` 30s governs
dimension choice (`knobs.rs:276-277`); caught-up CDC always takes `ts_page`.

## Framing / backpressure / cancellation

No SSE endpoint exists; closest precedents: `Body::from_stream`
(`local_backend/src/snapshot_export.rs:169-181`, `storage.rs:201,223`,
`http_actions.rs:274-303`) for `content-type: text/event-stream` with
`data:` events + `:` heartbeat comments; `stream_http_response`
(`http_actions.rs:210-256`) bridges via channel — but unbounded, explicitly
wrong for R5. Use bounded `channel(N)` (page-count + byte budget, actual
sizes from soft-limit overruns) with try-send → disconnect/shed, never grow.
Detect disconnect like `forward_http_action_stream`
(`http_routing.rs:291-309`: race stream vs sender-closed); chunked SSE (no
`Content-Length`) so disconnect propagates (cf. `http_actions.rs:293-302`).
Liveness shape from `logs.rs:38-71` (select entries vs timeout vs shutdown).
Keep empty `upToDate` advances server-local; SSE comments are transport
liveness only, never reactivity (R4). Reuse `DataSyncResponse` JSON per
event; route name, stream-version field, and status-event cadence stay
planning decisions.

## Cursor checkpoint + idempotency

Rule (R8/R9): group page entries by `ts` (every entry carries it), apply
each transaction atomically to Skip, persist the page cursor only after all
its Skip updates succeed. `data_sync.rs:20-48` guarantees no-split
transactions and per-document increasing `ts`, so disconnect-before-
checkpoint replay is idempotent iff Skip keeps per-`(component,table,_id)`
revision watermarks and drops `replayed_ts <= retained_ts`. Tombstones carry
`_id` only — Skip derives removes from retained values (needs a watermark
retention policy; planning question). Truncations apply before values in the
same page; `snapshotting` pages never activate (first `Stale`/`UpToDate` is
the boundary; staging generation + atomic promote, R6/R7).

## Failure mapping

Mid-stream expiry/validation errors terminate with a typed error event, never
a partial page as current (R11): reuse `cursor_expired_error` mapping
(`local_backend:530-544`), 400s for undecryptable cursor / bad selection /
cursor-ahead (`:558-573`), authz unchanged, usage/progress accounting
throttled (not per heartbeat). Restart losing Skip state → fresh snapshot;
expired/invalid cursor → fresh snapshot; retain last-good only if it exists,
mark stale, count the reason (R10).

## Acceptance

Wait = `wait_for_higher_ts` derivative with lost-wake protection; framing =
bounded SSE with disconnect-propagating cancellation; checkpoint =
cursor-after-apply with revision-watermark idempotency; failures typed and
never partial-current.

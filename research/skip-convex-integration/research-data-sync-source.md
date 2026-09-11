---
title: Data Sync source contract (Direction 1c/1d)
direction: 1c/1d
scope: research
status: grounded
verified_date: 2026-09-11
---

# Data Sync source contract (Direction 1c/1d)

What the existing `/api/v1/data/sync` API guarantees, so the push stream
reuses its contract instead of reimplementing snapshot/recovery. All paths
relative to repo root (`crates/...` for workspace crates) unless noted.

## Snapshot vs CDC

Two phases (`table_iteration/src/data_sync.rs:28-48`): `Snapshotting` pages
are not consistent; the first `Stale`/`UpToDate` page is the activation
boundary. Initial sync may re-emit a doc at increasing revisions. CDC emits
each captured doc at its version as of `ts`; transactions never split
across pages; selection change or bulk import can return to `Snapshotting`.

Two dimensions (`:57-98`): `by_id` walks one table at `synced_ts`
(`:495-523`, retention-bounded); `ts` walks the doc log forward
(`synced_ts.succ ..= latest`, `:608-641`), advancing `synced_ts` to the
last fully-consumed timestamp. Capture predicate (`:51-55,170-191`):
captured iff `ts <= synced_ts` and table already synced (or current table
with `id <= current_id`). Cold start (`:438-447`): `synced_ts = latest`,
no tables synced. `latest_ts = max(min_ts, persistence_max_repeatable)`
(`:405-422`) — lags live writes by seconds, monotonic, retention-bounded.

Every page is built from `latest_database_snapshot()`
(`application/src/streaming_export.rs:76-98`, `database.rs:2029-2044`);
`data_sync_iterator` passes `min_ts` + page/freshness knobs (`:567-578`).

## Revisions, tombstones, truncations

Internal `SyncEntry::Document{ts,component,table,doc}` vs
`Tombstone{ts,component,table,id}` (`streaming_export/src/lib.rs:64-83`);
truncations separate in `SyncResult` and logically **before** entries
(`:90,170,517-542`). `DocumentLogEntry{ts,id,value:None}` → tombstone with
`DeveloperDocumentId` (`:483-515`); `prev_rev` is delta-aggregation-only,
never on the wire (`data_sync.rs:290-308,381-402`).

Wire (`common/src/types/streaming_export/mod.rs:163-225`):
`DataSyncResponse{status,truncates,values,sync_id,pagination}`;
`DataSyncTruncate{component,table}` (first page, newly selected, import);
`DataSyncValue{component,table,ts:i64,deleted:bool,value:Map}` — live docs
carry `_id+_creationTime`, deleted carry `_id` only. Always
`ConvexExportJSON` (`local_backend/src/streaming_export.rs:576-632`).

## Cursors + retention

Opaque encrypted cursor (`streaming_export/src/lib.rs:178-208`,
`DATA_SYNC_CURSOR_VERSION=1`, protobuf + `RandomEncryptor`; wire decrypt →
400 `InvalidDataSyncCursor`, `:558-566`). Contents: `synced_ts`,
synced/in-progress tables, names, `sync_id` (`:185-195`,
`data_sync.rs:177-191`, proto `convex_data_sync.proto:11-49`). Caller must
persist Cursor+Page atomically (`data_sync.rs:20-26`).

Retention: index 4m, documents 14d (self-host 2d)
(`knobs.rs:636-659`). Cursor ahead of latest → 400; out-of-retention →
400 `DataSyncCursorExpired`, restart without cursor
(`local_backend/src/streaming_export.rs:530-544`). Progress rows keyed by
`sync_id`, active window 3d (`model/src/data_sync_progress/*`,
`application/src/streaming_export.rs:179-265`, throttled writes, flushed on
`UpToDate`).

## Selection + status + limits

Selection (`selection.rs:21-119`, `database/src/streaming_export_selection.rs`):
components → tables → columns; `_id` cannot be excluded; default
all-included; hidden tables included, system excluded by default
(`database.rs:993-1012`, `streaming_export/src/lib.rs:345-400`). Selection
may change between pages; newly selected syncs from scratch (possibly back
to `snapshotting` + truncate). Iteration in tablet order; reconcile drops
desynced/removed, starts added (`data_sync.rs:858-917`).

Status (`data_sync.rs:258-288`, `streaming_export/src/lib.rs:130-166,544-574`,
wire `:227-308`): `Snapshotting{progress}` (incomplete) |
`Stale{ts}` (behind) | `UpToDate{ts}` (caught up). Wire `Snapshotting`
strips progress (use list/get-active-syncs for observability,
`local_backend:338-466,634-650`).

Page limits are soft, transactions never split (`knobs.rs:238-260`:
16384 entries / 64MiB / 32768 rows; `data_sync.rs:22-26,538-735`):
single large txn can exceed; `by_id` emits the large doc anyway;
`ts_page` commits only on timestamp boundaries, overruns flagged, first row
of next ts carried over.

## Authz + endpoint behavior

Admin/system identity + `ensure_streaming_export_enabled` +
`require_operation(ViewData)` (`deployment:data:view`) on every route
(`streaming_export/src/lib.rs:444-447,598-601`,
`local_backend:395-398,451-454,553-556`). Routes: `POST /data/sync`,
`GET /data/list_active_syncs`, `GET /data/sync/{syncId}`
(`:264-308,375-443,519-528`); Deploy/Team/OAuth tokens; usage + egress
accounted per page (`:672-686`). Poll contract today: follow `nextCursor`,
pace on `status`, back off at `upToDate` (`:264-276,652-669`,
`mod.rs:182-188`).

## Acceptance

Push design reuses: phase/status activation rule, revision/tombstone/
truncate shapes, opaque cursor + retention errors, selection semantics,
soft-limit overflow behavior, authz baseline. Nothing here is re-specified.

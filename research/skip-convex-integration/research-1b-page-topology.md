---
title: 1b page topology (paginated reactive source)
type: research-note
status: active
direction: 1b
date: 2026-09-11
---

# 1b page topology (paginated reactive source)

How index-ordered Convex pages reach Skip as separate regions with atomic
split-swap, without flattening. Supports the 1b spike plan (R1-R15, F1-F3).
No backend changes; no claim that pages are row deltas.

## Pagination mechanics (verified)

- Contract: `pagination.ts:28-57` (`page`, `isDone`, `continueCursor`,
  `splitCursor?`, `pageStatus?: SplitRecommended|SplitRequired|null`);
  `numItems` is initial target only (`:68-78`); `cursor:null` = start;
  `endCursor` bounds `(cursor,endCursor]` for gapless adjacency (`:86-98`).
  `paginate()` returns all items in range after first call (`query.ts:212-229`).
- Split lifecycle (`paginated_query_client.ts:359-476`): detect on
  `splitCursor + (Recommended|Required|len > 2×initial)`; subscribe to
  `(cursor,split] + (split,continue]` with fresh keys, record
  `ongoingSplits`; complete only when both have results
  (`:369-383 → :532-544` splice + unsubscribe old). Old page stays in
  `pageKeys` until completion — the lifecycle R4 mirrors through Skip.
- `SplitRequired` = hard limit hit, page possibly incomplete — never publish
  as complete (R5; React truncates at `:343-348`). `Recommended` = soft
  3/4 rows/bytes or oversize (`async_syscall.rs:1685-1801`). `InvalidCursor`
  (fingerprint mismatch) → full reset with new `id`, not in-place handling.
- Backend split construction: `query/mod.rs:233-387` (Reactive-only
  split_cursor, fingerprint-gated end_cursor), `index_range.rs:65-329`
  (cursor-bounded unfetched interval, middle `split_cursor = intermediate
  [len/2]`, bounded pages ignore limits for correctness).
- Grouping: `onBaseTransition` fans changed tokens into one
  `ExtendedTransition` with `paginatedQueries` (`:244-273`) — satisfies R15
  without the 1a raw socket.

## Skip mapping (no flattening)

- One external resource per page → N Skip input dirs; each page update is
  `update(entries, isInit:true)` reconciled natively via `native_eq`
  (`EagerDir.sk`) with one tick per `writeInCollection` (`Runtime.sk`).
  No JS concat of the loaded window, no row diffing (R3).
- No public multi-region batch exists (`core/src/index.ts:476-501,768-782`;
  `CollectionWriter` fork/merge private): two calls = two ticks. Options:
  **A** tagged combined domain — one collection, page-tagged entries, one
  tick, but per-page `isInit` lost (patch + explicit deletes, window-wide
  enumeration); **B** scoped multi-region primitive — new `updateMany` or
  fork-handle FFI, per-page `isInit` preserved, needs Skip-side design;
  **C** per-page ticks + downstream merge — converges torn, fails R4/R6/R9,
  record as rejected. Planning chooses A vs B (plan Dependencies).
- Disjointness (R6) lives in a Skip-side mapper downstream of `merge`
  (`merge` unions same-key values, cannot enforce it): assert singleton
  `_id` (plain-`_id` keys) or `_id`-set overlap (tagged keys); throw or
  quarantine on violation, never silent dedup.
- Ordering: Skip `slice`/`take` follow Skip key order, not value order.
  Use order-preserving composite key (`[creationTime,_id]`, cf. chatroom's
  `-Number(id)` trick which does not transfer to opaque `_id`s) or a
  re-keying mapper before `take(N)` in `instantiate`. Sort-at-read is not
  reactive and insufficient. Keep `_id` + `_creationTime` in values;
  key by `row._id.toString()`; guard with `assertSkipJson`.

## Metrics without backend changes (R11-R13)

No per-page rows-read exposed to JS. Harness-side counts: received results,
live `pageKeys.length`, changed tokens per transition, query-set
add/remove, `ongoingSplits`, splits/rebuilds (`id` changes), delivered
`Σ page.length` + JSON bytes, end-to-end timers; per page via
`localQueryResultByToken` + `asPaginationResult` (actual length vs target,
`isDone`, cursors/status, pending, throws). Backend signals: `pageStatus`/
`splitCursor` frequency, `InvalidCursor`/limit errors + logLines, function
warnings, `TxMetricsJson` only via existing metrics syscall (not per page).
Report affected-`page.length` + Skip reconciled keys, never assumed
`numItems`. Fail runs that republish everything, omit splits, or report
time-only (R14).

## Reducer + failure posture

Loaded-window aggregate (e.g. per-user count `add:+1/remove:-1`) over merged
pages; split-swap generates removes + adds — atomic swap keeps it exact,
torn writes double-count transiently. `remove` may return `null` for full
recompute. On page failure/invalid cursor/reconnect: retain last-complete
window as stale, never label partial current (R10); load-more appends map to
added regions.

## Left to planning (sharpened)

Primitive choice (A vs B with rollback + `isInit` invariant); key/tag schema
(`_id` vs `[pageId,rowId]` vs `[creationTime,_id]`); per-option write mode;
disjointness mapper spec + failure action; order/window spec + `take`
placement; reducer definitions + torn-write probes; metrics/baseline for
R11-R13; harness reuse (`BaseConvexClient` vs `PaginatedQueryClient`
interface); deterministic injection of splits/cursor/failure/reconnect;
user-lookup source held constant; page/load/dataset scale points.

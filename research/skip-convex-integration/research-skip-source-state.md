# Skip source-state design (all spikes)

How Convex source data lives in Skip: combined input shapes, revision
watermarks, tombstones, ordering, restart-rebuild, and the fault list the
harnesses must inject. Serves 1a/1b/1c and the Direction 2 read path.

## Combined input (atomicity without a runtime change)

Constraint: N external writers = N fork/merge ticks with intermediates
visible (`core/src/index.ts:476-501`; no public `updateMany` or fork
handle; `ServiceInstance.update` batches one input collection only).
Recommended shape — **single namespaced-key collection**: one external
resource holding all tables, key `"<component>/<table>/<id>"` (or
`[table,_id]` tuple), value envelope
`{ts, deleted, component, table, _id, _creationTime, doc}`. One
`writer.update(entries, isInit)` per unit = one tick: per reassembled
Transition (1a), per `ts` group (1c), per page-group/swap (1b). Downstream
splits by table (`source.map(FilterMessages)` etc., cf. `ProjectsOnly` /
`TasksOnly`), aggregates via `map`+`reduce` / fused `mapReduce`, window via
`take(N)` in `instantiate` (chatroom precedent).

Tradeoff: single dir loses per-table `isInit` granularity — bootstrap sends
the full combined snapshot with `true`; steady state sends `false` deltas
with explicit `[key,[]]` deletes (`true` on partial = mass delete).
Truncation = explicit namespace deletes in the same update plus
generation-promote logic. Alternative per-table collections + downstream
`merge` is expressive but torn (two ticks) until an `updateMany`/fork-handle
primitive lands — keep as follow-up, not for atomicity proofs.

## Revision watermarks + GC

Skip's subscription `watermark` (`session/tick`) is in-run SSE resume only —
never reuse it for idempotency. Keep app-level per-`(component,table,_id)`
max-`ts` **in-value** (Data Sync entries already carry `ts`): apply iff
`entry.ts > retained_ts`, else count replayed/ignored. In-value travels
through `map/merge/reduce` with no second write; strip `ts` at the publish
boundary; reducers needing recency carry it explicitly. Side collections
double retained `O(N)` state for no recovery gain (and need the missing
batch primitive to stay consistent — derive instead if ever used).

GC: retain while the generation lives (same `O(N)` as the source itself);
wholesale discard on resnapshot/generation swap (table replacement, cursor
expiry, restart). Tombstone watermarks for deleted keys are the only leak —
sweep them once the cursor advances past the retention horizon (documents
14d / self-host 2d; index 4m) or on generation promote. Never retain
tombstones indefinitely without a policy; record `replayed/ignored` counts.

## Tombstones, ordering, restart

Wire tombstones carry `_id` only — Skip applies `[key,[]]` derived from the
retained value + watermark check. `native_eq` short-circuit plus correct
`Reducer.remove` (nullable → full recompute fallback) gives incremental
removal; adapter must not advance retained state until `update` resolves.
Group page values by `ts` (no-split-txn guarantee); persist the opaque cursor
only after all group updates succeed — disconnect-before-checkpoint replay
is then idempotent.

Ordering: Skip `slice`/`take` follow key order, not value order; opaque
`_id` keys cannot window a feed. Retain `_creationTime` in every envelope,
derive an order-key view (`[_creationTime,_id]`), `take(N)` downstream.
`_id` tiebreak mandatory. Never `take` in Convex (silent truncation reads
as deletion).

Restart/rebuild (all spikes): Skip state is process-local, derived,
rebuildable. Cold start builds a staging generation during `snapshotting`;
first `Stale`/`UpToDate` (or per-query first value) is the activation
boundary — never publish partial. Reconnect re-adds the set and takes fresh
values; expired/invalid cursor, table replacement, or lost Skip state →
fresh snapshot + staging rebuild + atomic promote; retain last-good only if
it exists, mark stale, count the reason. Failures typed, never
partial-current; freshness watermark never advances on failure.
`QueryFailed` freezes + stale indicator while `QueryRemoved` deletes inside
the enclosing atomic update. Direction 2 read path: version-gated freshness
with silent-but-counted native fallback; native result is the oracle.

## Fault injection (planning-owned)

Disconnect-before-checkpoint; cursor expiry/invalid/ahead; table
replacement + return to `snapshotting`; large txn exceeding soft limits
(16384 entries / 64MiB / 32768 rows); multi-table txn in one unit (needs an
app txn touching both tables); `QueryFailed` vs `QueryRemoved` vs
not-yet-loaded; slow consumer / bounded-backlog exhaustion; Skip-process
restart mid-CDC; page splits + invalid-cursor reset (1b). Harness:
parallel-reader comparator, writes paused at settled checkpoints anchored
on version timestamps, Skip SSE snapshot vs independent native query,
normalized deep-equal; counts + full timer chain alongside `O(K)` vs `O(N)`
curves.

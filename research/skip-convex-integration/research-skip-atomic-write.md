---
title: "Skip atomic write (R2/R3/R4)"
author: bill
direction: "Direction 1: Skip as reactive client"
scope: "1a-direct-sync-protocol-mapping"
key_topics:
  - "isInit/native_eq reconciliation"
  - "per-query fork/merge finding"
  - "missing batch primitive"
  - "no-diff rule"
  - "reducer bar"
---

# Skip atomic write (R2/R3/R4)

How each Transition becomes one atomic `isInit:true` write per query with no
hand-rolled diffing, and where the multi-query batch primitive is still
missing. Paths in `~/src/skip` unless noted.

## isInit:true reconciles natively and minimally

`skiplang/prelude/src/skstore/EagerDir.sk:1717-1729` (`writeEntry`): on each
key, `native_eq(new, old) == 0` returns early — no dirty marking, no reducer
work. Changed keys go through `DataMapValue::set` + reducer maintenance
(`:1767-1789`) + `context.addDirty` + child scheduling (`:1791-1840`).

`writeInCollection` (`skipruntime-ts/skiplang/core/src/Runtime.sk:1038-1065`):
`isInit:true` enumerates current keys, writes the full array, deletes
leftovers as `[key,[]]`; `isInit:false` is a patch (stale keys remain).
`isInit` is a caller assertion of full-snapshotness, not persisted state —
partial snapshot + `true` = mass delete. One `context.update()` per call =
one reactive tick and one subscriber notification set.

Cost of `true`: `dir.keys()` enumeration + per-key `writeEntry` (mostly
early-return) + full snapshot over FFI. No re-propagation for unchanged keys.
Correct iff the writer sends the query's full result every time.

## CollectionWriter: one fork/merge per query, no N-query batch

`skipruntime-ts/core/src/index.ts:476-501`: `update(values,isInit)` forks a
uuid-named context, runs `SkipRuntime_CollectionWriter__update` over FFI
(`binding.ts:70-74` → `FFI.sk:135-156` → `Runtime.sk:834-854` →
`writeInCollection`), then `merge()`; on any throw, `abortFork()` rolls back
and rethrows. `needGC` forbids writes inside mapper/reducer/`createGraph`
(`:1409-1411`).

`ExternalService` wiring (`core/src/api.ts:450-486`,
`core/src/index.ts:146-171,1211-1226`, `Runtime.sk:398-534`) is strictly
per-resource: N queries = N dirs/writers/subscriptions, each `update` its own
fork/merge tick. Two calls = two ticks; subscribers observe the intermediate.
`fork`/`merge` on `ToBinding` are public but `CollectionWriter` internals are
private, and `ServiceInstance.update` (`:768-782`) only batches single input
collections — there is **no public batch-N-external-writers-in-one-fork API**
today.

Options for R2: (a) new runtime/FFI `updateMany([(dir,values,isInit)])` or
exposed fork handle (needs Skip-side design); (b) single merged external
resource (loses per-query `isInit` granularity); (c) per-query ticks +
downstream `merge(...).mapReduce()` (eventual consistency, not atomic).
Current code has no (a).

## No-diff rule vs adapter baseline

Adapter (`adapters/convex/src/index.ts:133-163,214-371` on
`billf/convex/adapter`): retains a JS `Map` of the previous snapshot,
`isDeepStrictEqual` per key, emits only changed entries + deletes. The PoC
deletes all of that: send `rows.map(r => [getKey(r),[r]])` with `isInit:true`
every Transition. `native_eq` subsumes the deep compare; `dir.keys()`
subsumes the JS map. Rejected batches roll back the fork with main untouched;
the writer must not advance any JS-side pending state until `update`
resolves (adapter's `current`-advances-only-on-accept discipline, `:307-333`).

## Reducer bar for R4

Cross-table aggregate via `merge(q1,q2).map(M).reduce(R)` or fused
`mapReduce` (`Runtime.sk:593-666`, `index.ts:368-443`); native
count/sum/min/max available. Contract (`core/src/api.ts:81-109`): `remove`
may return `null` to force full recompute; non-null must equal the full
`add`-fold. Canonical example `tests/src/tests.ts:397-407`
(`initial:0, add:+1, remove:-1`). Reusable patterns in
`examples/chatroom/reactive_service/src/chatroom.service.ts`: `GroupByMessage`
fan-out mapper, constructor-injected dependent mapper for cross-collection
joins (`JoinUniqueLikers`), `take(limit)` in `instantiate` instead of source
limits.

## Gaps for planning

FFI batch signature or fork-handle exposure; `ConcurrentFork` behavior under
concurrent N-writer merges; enforcement of the full-snapshot invariant;
reducer `remove` correctness review for the chosen aggregate.

---
title: Abstract atomic-source-batch contract
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
---

# Abstract atomic-source-batch contract

Transitions (1a), page-group swaps (1b), timestamp groups (1c), and committed
transactions (Direction 2) are all their direction's indivisible source unit.
1a and 1b ingest **complete snapshots** while 1c and D2 ingest **revisioned
deltas**. The contract below separates transport-neutral invariants (all four)
from the two encodings, plus an explicit 1b mapping. No direction is asked to
adopt the other's input form.

## Transport-neutral invariants (all four directions)

- **Ordering:** source order is commit/`ts` order; per-document `ts`
  increases (`research-skip-source-state.md:42-49`).
- **Source consistency group:** each direction names the set of changes that
  must become visible together (1a: a Transition's modifications; 1b: a
  page-group swap; 1c: an exact-`ts` group; D2: one commit's changes).
  A split swap is one lifecycle event inside 1b's group handling — it is not
  itself a second consistency group.
- **No torn publication:** no subscriber-visible state in which only part of
  a consistency group has landed (1a `...1509...:120-121`; 1b
  `...1843...:188-189`; 1c `...1854...:217-218`; D2 `...1702...:84`).
- **Versioning:** `Transition.end_version.ts` / DataSync `ts`+`snapshotTs` /
  page-set version / commit version — opaque per direction, monotonic per
  source, recorded at every checkpoint (see
  `research-logical-checkpoint-contract.md` gate 1).

## Snapshot encoding (1a/1b only)

Complete per-query/per-page values, keyed by query ID (1a) or page-region
ID (1b), forwarded with `isInit: false` in one update per Transition or
swap; whole-collection `isInit: true` only when every live query/region is
included (bootstrap or reconnect), since a partial `isInit: true` empties
every omitted key (`Runtime.sk` `writeInCollection`) and reads as a mass
delete (shared P2/P3, updated 2026-09-23). Bridge-side diffing explicitly prohibited
(`research-sync-protocol-skip-mapping.md:70-72`;
`paginated-reactive-source-stable-page-snapshot-region` (1b R3)). Deletes
arrive as full new values (1a `QueryRemoved` inside the enclosing update —
`...1509...:51`) or region swaps (1b R4 — `...1843...:52`), never as
`[key,[]]` deltas computed by the bridge. Timestamped delta envelopes and
replay watermarks do **not** apply here.

## Revisioned-delta encoding and replay (1c/D2 only)

- **Tombstones:** `_id`-only on the wire → `[key,[]]` derived from the
  retained value + watermark check (`research-skip-source-state.md:60-66`);
  never resurrect via replay.
- **Replay / idempotence:** Skip's subscription `watermark` is SSE-resume
  only, never idempotency. App-level per-`(component,table,_id)` max-`ts`
  in-value: apply iff `entry.ts > retained_ts`, else count replayed/ignored;
  strip `ts` at the publish boundary
  (`research-skip-source-state.md:42-49`; P4 `...1159...:64`).
- **Atomic publication:** one `writer.update(entries,isInit)` per unit;
  cursor/watermark persisted only after all group updates succeed;
  disconnect-before-checkpoint replay is idempotent; never partial-current
  (`research-skip-source-state.md:26-28,64-66`).
- 1c checkpoint rule: group by `ts`, persist cursor only after all group
  updates succeed (`research-push-stream-seam.md:70-79`).

## Explicit 1b mapping: transition groups ↔ page-region swaps

1b consumes transition-grouped query updates (1b R15) but publishes
page-region swaps (1b R4): each underlying Transition's modifications land in
their page regions, and the swap of old→replacement regions is the single
atomic publication event. The Transition is 1b's transport grouping; the
page-group swap is its consistency group. Conflating them would either split
one swap across Transitions (torn) or force one update per Transition (loses
swap atomicity).

## Envelope + keying + `isInit` rules

Keying is shared: namespaced key `"<component>/<table>/<id>"`, order-key
`[_creationTime,_id]` (`research-skip-source-state.md:22-26`). The `ts`
envelope shape `{ts,deleted,component,table,_id,_creationTime,doc}`
(`...1159...:61-62`) belongs to the revisioned-delta encoding (1c/D2/P) —
snapshot directions (1a/1b) carry full values without `ts` envelopes.
`isInit` tradeoff: bootstrap full snapshot + `true`; steady state `false`
deltas + explicit `[key,[]]` deletes (partial + `true` = mass delete)
(`research-skip-source-state.md:32-34`;
`research-skip-atomic-write.md:22-31`). No public `updateMany`/fork-handle:
`CollectionWriter.update:476-501` and `ServiceInstance.update:768-782` are
single-collection-only (`research-skip-atomic-write.md:35-49`); options are new
primitive (needs design), single merged resource (loses per-query `isInit`),
or per-query ticks + `merge` (torn — rejected)
(`research-skip-atomic-write.md:51-55`).

## Per-direction mapping

| Direction | Source unit | Version | Tombstone path | Replay rule | Plan refs |
|---|---|---|---|---|---|
| 1a | reassembled Transition, all mods | `end_version.ts` | `QueryRemoved` deletes in enclosing update | fresh snapshot on reconnect | R2 `...1509...:48`; R9/R10 `...1509...:51-52`; no-bridge-diff `research-sync-protocol-skip-mapping.md:70-72` |
| 1b | page-group swap (both replacements complete) | page-set/query-set version | swap drops old region, no ghost | full reset on `InvalidCursor` | R4 `...1843...:52`; R5 `...1843...:54` |
| 1c | exact-`ts` timestamp group | revision `ts` + `snapshotTs` + opaque cursor | `_id`-only tombstone + watermark | ledger + generation-scoped watermarks, cursor after final group | R8-R9 `...1854...:79-80`; KTD7-KTD9 via P/P9 `...1854...:338-340` |
| D2 | committed transaction at one commit version | commit version + causal watermark | native delete path | staging rebuild + atomic promote | R1-R2 `...1702...:83-84`; cannot import P, reimplements natively `...1702...:377` |

GC convention: retain while the generation lives, discard on
resnapshot/swap, sweep watermarks past horizon (documents 14d, index 4m)
(`research-skip-source-state.md:51-56`; P5 `...1159...:65`).

## P-coverage vs residual gaps

Covered by P's snapshot baseline (P1-P3, P6-P8): single-fork invariant,
envelope/key/order helpers, no-runtime-change. Covered by P's revision-delta
extension (P4, P5, P9; required for 1c, never carried by 1a/1b as of
2026-09-23): in-value watermark, tombstone/GC convention, generation
fencing/ledger. Residual: FFI `updateMany`/fork-handle signature +
concurrent-fork semantics (`research-skip-atomic-write.md:81-85`);
per-direction version/cursor types; sweep horizon values; `remove → null`
correctness per aggregate.

## Open questions

- ~~P9 mandatory for 1b page-swap ledger or 1a reconnect, or 1c-only
  optional?~~ Resolved 2026-09-23 (shared-prereqs P9 scope entry): P9 is part
  of the revision-delta extension 1c consumes directly; 1a/1b state that
  revision watermarks and delta replay do not apply to their snapshot paths.
- Cursor-after-apply durability owner: client memory vs persisted (1c R9 vs
  D2 R6/R10)?
- Native batch primitive (option-a) vs permanent single-collection
  convention (`...1159...:68,250`)?

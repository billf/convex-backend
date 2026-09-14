---
title: 1b pagination boundary layers
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
  - 2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md
---

# 1b pagination boundary (fixed product / oracle / acquisition)

Resolves the apparent conflict between the Shared proof-vehicle contract
("take exactly 50, do not paginate") and 1b's reactive paginated acquisition
plus bounded loaded prefix. Three explicit layers preserve one common product
while allowing 1b's actual experiment.

## Layer A — fixed product semantics and canonical 50-row output

Governed by the Shared proof-vehicle contract
(`2026-09-11-1159-feat-skip-shared-prerequisites-plan.md:87-93`): five-table
schema with uniqueness rules (`:89`), required indexes
`by_room_user`/`by_room`/`by_message` (`:90`), canonical query (one room,
active-membership predicate, `(_creationTime desc, _id desc)`, take exactly
50, no pagination — `:91`), canonical projection (`sender: null` when missing,
`likeCount` counts likes rows even for missing liked users — `:92`). A spike
may vary only transport, lifecycle mechanics, and measurement (`:87`).

"Do not paginate" is a **product-query rule**, not a transport ban: the
canonical 50-row output is never assembled by concatenating client-visible
pages. 1b satisfies it at its merge/order point, not at acquisition.

## Layer B — native oracle over that output

1b's oracle is an independent monolithic native query implementing the
contract over the same loaded prefix, compared at settled checkpoints with
both paths reporting the same revision
(`2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md:63`,
`paginated-reactive-source-settled-monolithic-correctness` (1b R9)).
Normalization follows Q3/`research-spike-comparison.md:85-95` (canonical
`[_creationTime,_id]` order, nullable sender, exact `likeCount`).

Prefix shorter than 50 does **not** qualify for common-product correctness:
a prefix-scoped comparison can pass while omitting messages from the shared
canonical top-50 feed. Before 1b claims common-product correctness it must
acquire enough ordered source rows to determine 50 qualifying messages — or
prove the native result has fewer than 50 (oracle and feed agree on the
shortfall, same revision). Short-prefix runs remain valid topology tests
(page mechanics, splits, merge/ordering), but their correctness claims are
topology-scoped, never product-scoped.

## Layer C — source acquisition topology (1b may paginate internally)

Governed by `paginated-reactive-source-indexed-reactive-pagination` (1b R1)
(`...1843...:49`: `messages.by_room` + reactive pagination as cursor-bounded
pages; membership/user/like inputs preserve predicate and projection),
`paginated-reactive-source-bounded-prefix-load` (1b R2) (`...1843...:50`),
and `paginated-reactive-source-stable-page-snapshot-region` (1b R3)
(`...1843...:51`: stable per-page identity as its own snapshot region, no JS
concat, no row diffing).

Seam mechanics: `numItems` is initial-target only, `(cursor,endCursor]`
adjacency, `splitCursor`/`pageStatus`
(`research-1b-page-topology.md:17-20`); old page stays in `pageKeys` until
both replacements complete (`research-1b-page-topology.md:22-27`).

## The seam: pages → prefix → merged feed

Convex `paginate` → per-page snapshot regions (N Skip input dirs, no
flattening; per-page-ticks option C rejected as torn —
`research-1b-page-topology.md:42-53`) → Skip merge with disjoint-ID assertion
→ canonical ordering/projection (`paginated-reactive-source-disjoint-page-merge`
(1b R6), `...1843...:57`) → `take(50)` in Skip `instantiate` only, never
source-side (reads as mass deletion —
`research-spike-comparison.md:88-92`). Ordering/projection is produced at the
merge point (Layer A semantics) from page-local inputs (Layer C mechanism);
Skip `slice`/`take` follow key order, so the composite `[creationTime,_id]`
key or a re-keying mapper is required (`research-1b-page-topology.md:58-63`).

## R-mapping

| Layer | Governed by |
|---|---|
| A fixed output | Shared contract `:87-93`; 1b R6/R7/R9 oracle side |
| B oracle | 1b R9 (`...1843...:63`); Q3/Q4; 1b R13 monolithic comparison |
| C acquisition | 1b R1-R5, R8, R10-R14; topology doc mechanics |

## Open questions

- `take(50)` key schema: `_id` vs `[creationTime,_id]` composite (`research-1b-page-topology.md:90-93`).
- R4 atomic-swap primitive: tagged-combined (A, loses per-page `isInit`) vs
  scoped `updateMany`/fork-handle (B) vs P adoption (`...1843...:219,228`).

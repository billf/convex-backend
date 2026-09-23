---
title: PoC vehicle and harness
type: research-note
status: active
direction: 2
date: 2026-09-11
  - `sync-protocol-client-per-table-query-proof-input` (1a R8)
related_plans:
  - 2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md
serves:
  - Direction 2: proof queries, aggregates, harness (only citing plan)
pointers:
  - 1a readers: PoC vehicle in research-sync-protocol-skip-mapping.md §4
  - 1b readers: vehicle and scale points in the 1b spike plan + research-1b-page-topology.md
  - 1c readers: messages/users source tables in the 1c spike plan (fixed selection, `data-sync-push-fixed-selection-cursor` (1c R2))
  - All spikes: the binding vehicle is the Shared proof-vehicle contract in `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`, which supersedes the two-table vehicle below
---

# PoC vehicle and harness (`sync-protocol-client-cross-query-reducer` (1a R4)/`sync-protocol-client-settled-checkpoint-comparator` (1a R6)/`sync-protocol-client-chatroom-tutorial-proof` (1a R7)/`sync-protocol-client-per-table-query-proof-input` (1a R8))

> **Superseded vehicle (2026-09-14):** the two-table `messages`/`users`
> vehicle with aggregates A1/A2 below is retained as history. The binding
> proof vehicle for all four spikes is the **Shared proof-vehicle
> contract** in `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`
> (five tables, room-scoped feed, nullable sender, `likeCount`). Keying /
> encoding rules and the harness shape below still apply; schema, queries,
> aggregates, and oracle semantics follow the contract.

Freezes the demo shape: which queries, which aggregates, how keys work, and
how `sync-protocol-client-settled-checkpoint-comparator` (1a R6) correctness is checked. Plan Outstanding Questions that are answered
here are marked; the rest stay with planning.

## Convex tutorial today (fixture base only)

The tutorial (`~/src/convex-tutorial/convex/`) is the fixture base the
Shared proof-vehicle contract builds on, not the product contract. Binding
schema, indexes, queries, projection, and oracle semantics are the
contract's: `rooms{name}`, `users{name}`,
`memberships{room,user,active}` + `by_room_user`, `messages{room,sender,body}`
+ `by_room`, `likes{message,user}` + `by_message`; room-scoped feed with
active-membership predicate, `(_creationTime desc, _id desc)` order, exactly
50, no pagination; `{_id,_creationTime,room,body,sender,likeCount}` with
nullable `sender` (missing user → `null`, never `"Unknown"`).
`chat.ts:getMessages` (latest-50 + user-name join + reverse) is
**forbidden by `sync-protocol-client-per-table-query-proof-input` (1a R8)**; the membership filter, join, ordering, limit, and `likeCount`
move into Skip.

Required fixture additions (app-layer, not backend): rooms/memberships/
likes tables + indexes, deterministic mutations (rename, activation,
like add/remove, dangling sender, multi-table txn), a bounded
canonical-result query, and an all-selected-rows baseline query.
Unbounded `collect()` is fine at PoC scale; any future bounding must fail
loudly (silent `take` in Convex would read as mass deletion downstream).
Whether tutorial UDF additions count as prohibited "backend change" is
unstated — planning to confirm, presumed allowed.

## Aggregates (fixed by the Shared proof-vehicle contract)

The contract fixes the aggregate set: the room-scoped feed (active-membership
filter, nullable-sender join, deterministic order, bound 50) plus the
per-message `likeCount` reducer with exact inverse removal. The reducer bar
(`sync-protocol-client-cross-query-reducer` (1a R4)) is carried by
`likeCount`. Retired candidates below are history — do not build them.

- ~~A1 (proves the engine): per-user message count.~~ Retired: the contract's
  `likeCount` reducer proves the engine instead.
- ~~A2 (proves join parity): enriched latest-N feed mirroring `getMessages`
  without the Convex join.~~ Retired: the contract's room feed with nullable
  sender (missing user → `null`, never `"Unknown"`) proves join parity
  instead.

Patterns reused from
`skip/examples/chatroom/reactive_service/src/chatroom.service.ts`:
`GroupByMessage` fan-out, constructor-injected dependent mapper for
cross-collection joins, `take` in `instantiate`, two-external `createGraph`.

## Keying / encoding

- `getKey = row._id.toString()`: stable, non-empty, unique (contract:
  duplicates/empty/non-string throw). Never key by `body`/`name`.
- Ordering: chatroom's negative-numeric-ID trick does not transfer to opaque
  Convex `_id` strings; latest-50 needs an explicit order key
  (`_creationTime` + `_id` tiebreak) or Skip order diverges from the contract's
  `(_creationTime desc, _id desc)` feed order.
- Encoding: current schema is JSON-safe (strings + numeric `_creationTime`);
  no `int64`/`bytes` encoders needed. Keep `_id`/`_creationTime` in Skip values
  (dropping them breaks keying/ordering); `assertSkipJson`
  (`skipruntime-ts/adapters/convex/src/index.ts:109-131`) remains the boundary guard.
- Stability: regenerated synthetic keys defeat `native_eq` and look like
  mass delete+insert under `isInit:true`.

## `sync-protocol-client-settled-checkpoint-comparator` (1a R6) harness (the biggest gap)

No harness exists. Feasible shape: parallel-reader comparator — (a) PoC Skip
service exposing the room feed over SSE (`POST /v1/streams/:resource` +
`GET /v1/streams/:uuid`), (b) independent reader (`ConvexClient` or
`convex-test`) on the same five plain per-table queries. (Updated 2026-09-23: the
shared plan's Q2 defaults to `ConvexClient` on the same deployment; `convex-test`
is a separate database and is admitted only after Q13's loader replays the same
manifest and mutation log and a per-table parity check passes.) Drive writes through the app,
anchor point-in-time on `Transition.end_version.ts`, snapshot the Skip
resource per Transition, compute the expected feed locally (membership filter
+ nullable sender, per-message `likeCount`, explicit sort), deep-equal after normalization.

- Atomicity probe (`sync-protocol-client-live-cross-table-aggregate` (1a F1)/`sync-protocol-client-atomic-cross-table-update` (1a AE1)): needs a multi-table mutation (current
  `sendMessage` touches only `messages`; e.g. membership change + like add in one
  transaction) so one Transition carries every affected table's `QueryUpdated`s. Assert no
  intermediate render shows one table advanced without the other.
- Failure probe (`sync-protocol-client-query-failure-recovery` (1a F2)/`sync-protocol-client-stale-last-good-on-failure` (1a AE2)/`sync-protocol-client-last-good-failure-state` (1a R5)): force `QueryFailed`, assert frozen last-good +
  visible stale indicator, then recovery to matching on the query's fresh complete value (`isInit:false`, shared P3).
- Frozen values must be surfaced as possibly-stale, never as current.

## Left to planning

Auth mode (plan-deferred as product-irrelevant); tutorial-UDF-allowed
confirmation; sidecar vs embedded packaging and the five-query single-fork
wiring from the atomic-write note. (Aggregate set, N=50, and order spec are
fixed by the Shared proof-vehicle contract — no longer open.)

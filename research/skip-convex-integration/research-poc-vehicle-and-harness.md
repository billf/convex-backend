# PoC vehicle and harness (R4/R6/R7/R8)

Freezes the demo shape: which queries, which aggregates, how keys work, and
how R6 correctness is checked. Plan Outstanding Questions that are answered
here are marked; the rest stay with planning.

## Convex tutorial today

`~/src/convex-tutorial/convex/schema.ts`: `messages{user: Id<users>,
body: string}` + `by_user`, `users{name}` + `by_name`. Every doc also carries
`_id` + `_creationTime` on the wire. `chat.ts`: `sendMessage` (insert) and
`getOrCreateUser` (lookup-or-insert) stay as the write path — writes never go
through Skip. `getMessages` (latest-50 + user-name join + reverse) is
**forbidden by R8**; the join and limit move into Skip.

Zero plain per-table queries exist. Required additions (app-layer, not
backend): `listMessages` (`collect()` of `messages`) and `listUsers`
(`collect()` of `users`). Unbounded `collect()` is fine at PoC scale; any
future bounding must fail loudly (silent `take` in Convex would read as mass
deletion downstream). Whether tutorial UDF additions count as prohibited
"backend change" is unstated — planning to confirm, presumed allowed.

## Aggregates (answers R4 candidate choice)

Tutorial has no rooms, so plan AE1/AE2 "per-room count" is not directly
mappable — do not add a rooms table without a planning decision. Ship both:

- A1 (proves the engine): per-user message count. `Mapper: message →
  [message.user, 1]` + `Reducer{initial:0, add:+1, remove:-1}` O(1),
  optionally joined with `users` for display names. Spans both tables.
- A2 (proves join parity): enriched latest-N feed mirroring `getMessages`
  without the Convex join. `Mapper(usersCollection): message →
  [{...message, name: users.getArray(message.user)[0]?.name ?? "Unknown"}]`
  (pattern: chatroom `JoinUniqueLikers`), `Resource.take(N)` in Skip (pattern:
  chatroom `MessagesResource`, N = 25 or 50). A2 alone as pure map does not
  satisfy R4's reducer bar — A1 carries it.

Patterns reused from
`skip/examples/chatroom/reactive_service/src/chatroom.service.ts`:
`GroupByMessage` fan-out, constructor-injected dependent mapper for
cross-collection joins, `take` in `instantiate`, two-external `createGraph`.

## Keying / encoding

- `getKey = row._id.toString()`: stable, non-empty, unique (contract:
  duplicates/empty/non-string throw). Never key by `body`/`name`.
- Ordering: chatroom's negative-numeric-ID trick does not transfer to opaque
  Convex `_id` strings; latest-N needs an explicit order key
  (`_creationTime` + `_id` tiebreak) or Skip order diverges from `getMessages`.
- Encoding: current schema is JSON-safe (strings + numeric `_creationTime`);
  no `int64`/`bytes` encoders needed. Keep `_id`/`_creationTime` in Skip values
  (dropping them breaks keying/ordering); `assertSkipJson`
  (`adapters/convex/src/index.ts:108-131`) remains the boundary guard.
- Stability: regenerated synthetic keys defeat `native_eq` and look like
  mass delete+insert under `isInit:true`.

## R6 harness (the biggest gap)

No harness exists. Feasible shape: parallel-reader comparator — (a) PoC Skip
service exposing the aggregate over SSE (`POST /v1/streams/:resource` +
`GET /v1/streams/:uuid`), (b) independent reader (`ConvexClient` or
`convex-test`) on the same two plain queries. Drive writes through the app,
anchor point-in-time on `Transition.end_version.ts`, snapshot the Skip
resource per Transition, compute the expected aggregate locally (count + join
with `"Unknown"` fallback, explicit sort), deep-equal after normalization.

- Atomicity probe (F1/AE1): needs a multi-table mutation (current
  `sendMessage` touches only `messages`; e.g. message + user-touch in one
  transaction) so one Transition carries both `QueryUpdated`s. Assert no
  intermediate render shows one table advanced without the other.
- Failure probe (F2/AE2/R5): force `QueryFailed`, assert frozen last-good +
  visible stale indicator, then recovery to matching on fresh `isInit:true`.
- Frozen values must be surfaced as possibly-stale, never as current.

## Left to planning

Aggregate set + N and order spec; auth mode (plan-deferred as
product-irrelevant); tutorial-UDF-allowed confirmation; sidecar vs embedded
packaging and the two-query single-fork wiring from the atomic-write note.

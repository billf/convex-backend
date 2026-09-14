---
title: "Sync-protocol → Skip mapping"
type: research-note
status: active
direction: 1a
date: 2026-09-11
---

# Sync-protocol → Skip mapping (sub-direction 1a)

Thinking log: 1a mandates a Skip client speaking the real `/api/sync`
WebSocket protocol directly, with no convex-backend changes. The open
question is not whether the wire is reachable (grounding proves a
protocol-agnostic Rust client exists) but how wire concepts map onto Skip
concepts without reintroducing the `ConvexClient.onUpdate` + Node-diff hop
the `billf/convex/adapter` baseline is measured against. This doc publishes
that mapping so a PoC agent can build without re-deriving protocol facts.
Sibling scopes 1b (query shaping), 1c (backend change events), and Direction
2 (native Skip in backend) are explicitly out of scope and not designed
around here.

## 1. Wire facts (verified, not inferred)

Endpoint: WebSocket to `<deployment>/api/sync`, JSON messages both ways.
No browser-specific handshake (grounding: Rust
`crates/convex/src/sync/web_socket_manager.rs:96-115` (`SyncProtocol::open`; tungstenite import at `:38`, `connect_async` at `:315`) opens the same socket
via `tokio_tungstenite`; TS mirrors it).

Client → server (`sync_types/src/types/mod.rs:171-206`):
- `Connect { session_id, connection_count, last_close_reason,
  max_observed_timestamp, client_ts }` — opens/resumes a session.
- `ModifyQuerySet { base_version, new_version, modifications: Add/Remove }`
  — demand signal for which queries are live.
- `Mutation` / `Action { request_id, udf_path, args }` — write path (1a PoC
  does not need it; mutations go through the tutorial app directly).
- `Authenticate { base_version, token }` — `AuthenticationToken:
  Admin(key, attrs?) | User(jwt) | None` (`:291-300`); no cookies.
- `Event` — analytics only.

Server → client (`:342-387`):
- `Transition { start_version, end_version, modifications,
  client_clock_skew, server_ts }` where `StateVersion = { query_set,
  identity, ts }` (`:325-340`).
- `modifications: StateModification<V>` = `QueryUpdated { query_id, value,
  log_lines, journal }` | `QueryFailed { … }` | `QueryRemoved { query_id }`
  (`:305-323`). Critical: `value` is the query's **full new result**, and the
  `modifications` vector contains **only queries that changed** — per-query
  deltas, not row-level deltas within a query — **bundled atomically per
  Transition**: one Convex commit spanning two tables arrives as one
  Transition carrying both `QueryUpdated` mods together.
- `TransitionChunk { chunk, part_number, total_parts, transition_id }`
  (`:355-364`) for large transitions; TS reassembles by joining chunks in
  order then parsing once
  (`browser/sync/web_socket_manager.ts:300-347`, join at `:334`, order check
  at `:322`). Server splits UTF-8-safely only when the client negotiates
  chunk support (`local_backend/src/subs/mod.rs:maybe_split_transition`).
- `MutationResponse` / `ActionResponse` / `AuthError` / `FatalError` / `Ping`.

Liveness (Rust worker, `sync/web_socket_manager.rs:132-169`): 5s heartbeat
pings, 30s server-inactivity timeout, backoff reconnect carrying
`last_close_reason` + `max_observed_timestamp`. `max_observed_timestamp` /
`end_version.ts` is a **causal watermark, not a durable replay cursor** —
on reconnect the client re-establishes subscriptions and takes fresh values.

## 2. Wire → Skip mapping

| Wire concept | Skip concept | Rule |
|---|---|---|
| `ModifyQuerySet` Add/Remove | `ExternalService.subscribe` / `unsubscribe(instance)` | Query set is demand-driven: resource `instantiate` subscribes, release unsubscribes. One `query_id` per live resource instance. |
| `QueryUpdated{query_id, value}` | `callbacks.update(entries, isInit)` or `update(collection, entries)` | Forward the **full** per-query value as Entries; do **not** bridge-diff. Skip's `isInit:true` write path already performs exact minimal reconciliation natively — bridge-side `isDeepStrictEqual` diffing (the adapter's `diffSnapshot` pattern) is redundant work reintroduced one process over. Keep a per-`query_id` last value only to know what to drop on error/reconnect, never to compute deltas. Changed queries only — untouched `query_id`s emit nothing. |
| Whole-Transition atomicity | single fork/merge batch per Transition | One Transition's `modifications` must land in Skip as **one** batched write (all `QueryUpdated` values in that Transition together, cf. `CollectionWriter.update` fork → `update_` → `merge`, `core/src/index.ts:476-487`). This is the evidenced correctness property the adapter structurally lacks: its per-resource `callbacks.update` calls tear one bundled commit into separate per-query callbacks with no atomicity. |
| First value per `query_id` | `isInitial:true` batch | Bootstrap and post-reconnect/post-reject recovery both deliver a fresh full snapshot as initial. |
| `end_version.ts` | Skip `watermark` (opaque string) | Record per-`query_id` watermark for SSE resume within a run; never treat as a cross-restart replay cursor. |
| `QueryFailed` | `callbacks.error` + teardown/re-subscribe | Surface, drop last value, re-subscribe → fresh initial (recovery, not replay). |
| `QueryRemoved` | `unsubscribe` completion | Drop last value + watermark. |
| Row identity | `getKey(row): string` | Non-empty, stable across snapshots; duplicates throw; non-string keys throw. |
| Row values | `Entry<Json,Json>` | Must pass `assertSkipJson` (`skipruntime-ts/adapters/convex/src/index.ts:109-131`): `bigint`/`ArrayBuffer` rejected at boundary with encoder hint. |
| Auth token | Service-held credential | PoC: unauthenticated or admin key per tutorial deployment; production shape (per-tenant JWT, gateway) is out of scope for 1a correctness-only bar. |

Ordering/dedup: serialize deliveries per instance (promise chain); drop
stale generations after reconnect (adapter `:274-332` pattern); enforce
`base_version` match on `ModifyQuerySet` or reset the query set.

## 3. Recommended structure (from 1a brainstorm, as corrected)

Sidecar bridge over embedded client: a standalone sync-protocol process owns
the socket (Connect → Authenticate → ModifyQuerySet loop, chunk reassembly,
backoff) and writes Entry batches into Skip **without diffing**; the Skip
service owns only graph + reducers. Rationale: reuses the proven Rust/TS
client behavior instead of reimplementing it inside the reactive service,
keeps wire vs. compute failures isolable, and — with bundle-preserving
writes — carries the cross-query atomicity the adapter cannot. Embedded
`ExternalService`-speaks-WS is the fallback if a second process is too heavy
for the PoC. Demand-driven query set (resource demand → ModifyQuerySet
Add/Remove) is not a separate third approach; it is part of this recommended
design's baseline (§2 row 1).

## 4. PoC vehicle (chatrooms × tutorial)

- Convex side (`~/src/convex-tutorial/convex/`): `schema.ts` (`messages{user,
  body}` + `by_user`, `users{name}` + `by_name`); `chat.ts:getMessages`
  returns latest 50 reversed + joined `name`. Writes via `sendMessage` /
  `getOrCreateUser` from the app, not through Skip.
- Skip side (pattern from `skip/examples/chatroom/reactive_service/src/
  chatroom.service.ts`): external messages collection → `map`/`reduce`
  derivations → subscribable resource. 1a aggregate proving the incremental
  engine: per-user (tutorial has no rooms) message count via
  `Reducer{initial:0, add:+1, remove:-1}` O(1), plus the joined
  latest-N view. A relay emitting snapshots without a reducer does not
  satisfy the 1a bar.
- Correctness bar only (per 1a decisions): end-to-end works, Skip-served
  results equal Convex query results, aggregate updates incrementally on new
  messages. No latency benchmark vs the adapter branch required.

## 5. Failure matrix (must handle, must not replay)

Bootstrap reject → resubscribe with backoff, then fresh initial. Mid-stream
reject → teardown that `query_id`, re-subscribe, fresh initial. Reconnect →
`Connect` with `last_close_reason` + watermark, re-add query set, fresh
values. Max-attempts → inert subscription requiring explicit re-create.
Restart (either side) → full recompute; all stream IDs invalidated. Capped /
truncated queries must fail loudly (truncation is indistinguishable from
mass deletion).

## 6. Acceptance for a 1a PoC reader

- Socket lifecycle implemented without `ConvexClient`: Connect, Authenticate,
  ModifyQuerySet, Transition/Chunk handling, heartbeat/timeout/backoff.
- Bundle-preserving writes with **no bridge diffing**: full per-query values
  forwarded, native runtime reconciliation relied on, stable keys, `[key,[]]`
  deletes, `isInitial` on bootstrap/recovery, watermark recorded.
- Demand-driven query set (subscribe on instantiate, remove on release).
- Tutorial messages flowing into Skip with a real `add`/`remove` aggregate
  and SSE-readable resource matching Convex data.
- Non-goals respected: no polling emulation, no 1b query-shaping dependency,
  no 1c backend changes, no Direction-2 native execution, no publish
  packaging.

## Sources

Grounding `## Sync protocol wire format`; `research-convex-reactivity.md`
(coarse-invalidation model); `research-skip-engine.md` (Mapper/Reducer);
`research-skip-externals-adapter.md` (adapter teardown baseline);
`research-skip-client-v2.md` (bounded-query contract, superseded on transport
choice by the 1a mandate — see its addendum).

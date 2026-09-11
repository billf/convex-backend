---
title: Sync wire TS checklist (R1/R2/R5)
type: research-note
status: active
direction: 1a
date: 2026-09-11
---

# Sync wire TS checklist (R1/R2/R5)

What an in-process TypeScript client must implement to speak `/api/sync`
directly. No `ConvexClient`, no backend changes. All paths under
`/Users/bill/src/convex-backend` unless noted.

## Transport / endpoint

- Open WebSocket to `ws(s)://<deployment>/api/<version>/sync`. JS builds
  `wsUri` from origin (`browser/sync/client.ts:324-339`); server route is
  `/{client_version}/sync` (`local_backend/src/router.rs:286-290`).
- Client version: server prefers `Convex-Client` header (`{client}-{semver}`),
  falls back to URL path (`common/src/http/mod.rs:947-980`,
  `common/src/version.rs:375-384`). Rust sends `rust-<version>` with
  `Convex-Client` on WS connect (`convex/src/sync/web_socket_manager.rs:310-314`,
  `convex/src/client/mod.rs:140-143`).
- JSON text frames only; server rejects non-`Text`, auto-handles WS Ping/Pong
  (`local_backend/src/subs/mod.rs:152-196`). Invalid JSON → `bad_request`
  (`:167-175`).

## ClientMessage (`convex/sync_types/src/types/mod.rs:171-206`)

- `Connect { session_id (Uuid), connection_count (u32),
  last_close_reason, max_observed_timestamp?, client_ts? }` (`:173-179`).
- `ModifyQuerySet { base_version, new_version, modifications: Add/Remove }`
  (`:180-184`). `Query { query_id (u32), udf_path, args, journal?,
  component_path? }` (`:104-117`); `Add(Query)` / `Remove{query_id}`
  (`:119-123`). `args` is array-wrapped Convex JSON (`base_client/mod.rs:147-148`,
  `browser/sync/client.ts:974-980`).
- `Mutation` / `Action { request_id (u32), udf_path, args, component_path? }`
  (`:185-200`). `component_path` is dashboard/admin-only. Read-only PoC can
  omit both send paths and their responses.
- `Authenticate { base_version, token }` (`:201-204`) with
  `AuthenticationToken: Admin(key, attrs?) | User(jwt) | None` (`:291-300`).
- `Event { event_type, event }` (`:205-212`) — analytics only, omittable.

Wire JSON (`sync_types/src/types/json.rs`, mirror
`browser/sync/protocol.ts`): `u64` as base64-LE string (`json.rs:53-62`,
`protocol.ts:10-18`); client envelope lifts `args`/`modifications` top-level
(`json.rs:176-188`); `StateVersion { querySet, identity, ts }`
(`json.rs:449-477`); `udfPath` canonicalized `module:fn`
(`browser/sync/udf_path_utils.ts:3-18`); values are Convex-JSON
(`convex/src/values/value.ts:228-247,340-485`).

## ServerMessage handling

- `Transition { startVersion, endVersion, modifications,
  clientClockSkew?, serverTs? }`: validate `startVersion` equals local
  version (`base_client/mod.rs:320-326`, `remote_query_set.ts:30-40`), apply
  **all** modifications then set version to `endVersion` as one step
  (`:327-367`, `:41-87`). This is the R2 atomic unit — whole
  `modifications` array goes to Skip as one batch, never per-query writes.
- `StateModification`: `QueryUpdated{query_id, value (full new result),
  logLines, journal}` | `QueryFailed{…, errorMessage, errorData?}` |
  `QueryRemoved{query_id}` (`mod.rs:305-323`, `json.rs:479-586`).
- `QueryFailed` freeze (R5): stock clients overwrite with failure
  (`remote_query_set.ts:58-74`, `base_client/mod.rs:341-359`); the PoC must
  instead retain last-good rows and surface staleness, resuming `isInit:true`
  writes on recovery.
- `TransitionChunk { chunk, partNumber (0-indexed), totalParts,
  transitionId }`: buffer, strict order check (`partNumber == length`),
  `join("") → parse → assert Transition` (`web_socket_manager.ts:300-347`);
  interleaved non-chunk clears the buffer (`:457-462`). Server splits only if
  negotiated chunk support (`subs/mod.rs:229,377-388`, threshold 5MB heap
  estimate, UTF-8-safe slices); support = `NPM && semver >= 1.28.0`
  (`:353-371`) — otherwise Rust/all others get whole Transitions. New client
  chooses: advertise `npm>=1.28.0` and implement reassembly, or advertise
  otherwise and accept up to 5MB messages.
- `MutationResponse`/`ActionResponse`: ignorable for read-only PoC
  (`client.ts:478-499`, `base_client/mod.rs:663-716`).
- `AuthError`: fatal protocol restart (`base_client/mod.rs:684-696`).
- `FatalError`: terminate, do not retry (`client.ts:504-507`).
- Protocol `Ping`: ignore except inactivity timer (`web_socket_manager.ts:440-443`).

## Lifecycle (no ConvexClient)

- `sessionId` UUIDv4 per client instance; `connectionCount` increments per
  `onopen`; `lastCloseReason` starts `"InitialConnect"`
  (`web_socket_manager.ts:158-164,409-410`).
- On open send `Connect{…, maxObservedTimestamp, clientTs: Date.now()}`
  (`client.ts:421-429`). Track `maxObservedTimestamp = max(endVersion.ts,
  mutation ts)` (`client.ts:545-556`, `base_client/mod.rs:632-652`); resend on
  every reconnect.
- `queryId`/`querySetVersion`/`identityVersion` from 0
  (`local_state.ts:65-75`, `base_client/mod.rs:108-117`); subscribe =
  `ModifyQuerySet{Add}` with canonical path + array args (`local_state.ts:88-153`);
  unsubscribe = `ModifyQuerySet{Remove}` (`:371-405`). Persist per-query
  `journal` for resend (`:155-184,285-287`).
- Reconnect = discard remote set, `restart()`: resend auth, re-add all live
  queries (`baseVersion:0 → 1`), replay outstanding mutations
  (`client.ts:431-444`, `local_state.ts:289-334`). No durable replay —
  re-snapshot by design.
- Liveness: server WS Ping every 5s, client timeout 120s (`subs/mod.rs:94-97`);
  JS protocol-Ping ~15s / inactivity 60s → reconnect (`web_socket_manager.ts:235-239,557-569`);
  Rust tick 5s / 30s → bail (`sync/web_socket_manager.rs:134-136,241-246`).
  Backoff JS `100ms·2^retries` cap 16s + jitter, reset only after syncing past
  reconnect (`web_socket_manager.ts:114-149,470-475`); Rust `100ms→15s`
  (`:60-61`). Retry even on close `4040` (`:11-19,484-505`).

## De-risking spike (still JS client, not deliverable)

`BaseConvexClient.addOnTransitionHandler(fn({queries, reflectedMutations,
timestamp}))` (`client.ts:246-250,618-637`) exposes whole Transitions to
validate the atomicity claim before building the raw socket.

## Unknowns left to planning

Auth mode (None/Admin/User JWT); `Convex-Client` version string + chunk
opt-in; `sessionId` reuse vs fresh per socket; `QueryRemoved`→Skip mapping;
`journal` round-trip for non-paginated queries; exact demo queries/aggregate.

---
title: 1a review answers (QueryRemoved, chunks, tractability, bar)
type: research-note
status: active
direction: 1a
date: 2026-09-11
---

# 1a review answers (QueryRemoved, chunks, tractability, bar)

Closes the four 2026-09-10 review questions on the 1a sync-protocol client
plan. Each answer is a planning instruction, not a redesign.

## 1. QueryRemoved → delete inside the atomic unit

`QueryRemoved{query_id}` carries no value
(`sync_types/src/types/mod.rs:320-322`, `json.rs:517-520,549-550`). The
server sends it only as the echo of the client's own unsubscribe
(`sync/src/worker.rs:970-981`) — never spontaneously. Stock clients delete
the local entry silently (`browser/sync/remote_query_set.ts:75-77`,
`local_state.ts:173-175`, `convex/src/base_client/mod.rs:360-362`) and emit
no removal event to UI (`client.ts:566-616` only ever emits Updated).

Skip rule: mirror the delete translated into Skip writes, folded into that
Transition's atomic unit — write the query's key with an empty value
(`isInit:false`, shared P2/P3 as of 2026-09-23) in the same batch, never as a separate write and
never ignored. Ignoring orphans rows that keep feeding the cross-table
reducer (e.g. ghost room after room-switch). Distinct from `QueryFailed`
(`sync-protocol-client-last-good-failure-state` (1a R5) freeze-at-last-good): Removed = deliberate client action → delete;
Failed = server error → freeze + stale indicator. PoC-scope note: static
per-table subscriptions never unsubscribe, so this never fires in the demo —
state the rule anyway in one sentence.

## 2. Chunks: eligible, atomicity via reassemble-then-write-once

Server splits only `Transition`s over ~5MB heap for chunk-negotiated clients
(`local_backend/src/subs/mod.rs:353-422`): `supports_transition_chunks =
(NPM && semver >= 1.28.0)` (`common/src/version.rs:47-54`); all other types
→ whole messages. Browser WS carries the version in the URL path
(`browser/sync/client.ts:339`, `version 1.45.0`; `router.rs:286-290`,
`http/mod.rs:947-980`, `version.rs:375-384`), so a from-scratch TS client
advertising `npm>=1.28.0` **is chunk-eligible**: small demo transitions
arrive whole, large ones arrive as `TransitionChunk{chunk, partNumber,
totalParts, transitionId}`. Do not dodge by version-spoofing older.

Reassembly (`web_socket_manager.ts:300-347`): validate
partNumber/totalParts/transitionId, enforce in-order append, `join("") →
parse → assert Transition`; interleaved non-chunk clears the buffer
(`:457-462`). Rust rejects chunks outright (`base_client/mod.rs:720-724`),
proving the gating. Planning instruction: the Skip write happens once per
**reassembled** Transition. `sync-protocol-client-atomic-transition-apply` (1a R2)'s atomic unit is post-reassembly, never one
write per chunk. Demo-scale transactions never exercise this path; record it
as untested-at-scale.

## 3. Raw-client tractability beyond the spike

`addOnTransitionHandler` (`browser/sync/client.ts:633-637`) validates one
claim — transactions arrive whole — inside the stock client. It exercises
none of what the PoC would own: Connect lifecycle (sessionId,
connectionCount, lastCloseReason, maxObservedTimestamp, clientTs),
Authenticate state machine (cached → fresh → pre-expiry refetch,
reauth-on-AuthError; `authentication_manager.ts:53-136,150-325`),
ModifyQuerySet versioning + restart-vs-resume with journals
(`local_state.ts:88-153,289-364`), mutation/action correlation + resend
(`request_manager.ts:168-230`), heartbeat/liveness (server 5s/120s,
`subs/mod.rs:94-97`; TS 60s inactivity, Rust 5s/30s), backoff with
synced-past-reconnect reset (`web_socket_manager.ts:870-883,470-475`),
full QuerySet resend on open (`client.ts:421-444`), version negotiation
(header vs URL path), and chunk reassembly above. Planning instruction:
scope the PoC socket to the minimal subset it implements (Connect + static
ModifyQuerySet + Transition read path + Ping, auth mode pinned) or
acknowledge re-implementing a sizable fraction of `browser/sync/*` +
`convex/src/sync/*`.

## 4. What passing `sync-protocol-client-settled-checkpoint-comparator` (1a R6) does not establish

`sync-protocol-client-settled-checkpoint-comparator` (1a R6) (Skip aggregate matches Convex at the same version) plus explicit
non-requirements leaves generalizability to judgment: reconnect/resumption
(full resend + re-snapshot, no durable replay), >5MB chunk path, multi-session
and token refresh/expiry (whole-set invalidation, `worker.rs:954-966`),
mutation/action lifecycle (PoC is subscribe-only), unsubscribe/resubscribe
(`QueryRemoved` never fires statically), and all performance behavior of
per-transition complete-value writes. Keep `sync-protocol-client-settled-checkpoint-comparator` (1a R6) as the PoC gate; append a
"what passing `sync-protocol-client-settled-checkpoint-comparator` (1a R6) does not establish" note listing exactly these, so the
worth-generalizing call stays explicit.

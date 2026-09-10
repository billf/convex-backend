# Skip-as-client v2 (Track 1 construction spec)

Augments `research-skip-externals-adapter.md` §6. Does not repeat the
externals model, `ExternalService` shape, or adapter teardown already covered
there. Resolves its five "better integration" gaps with a buildable choice.

## Baseline (what exists, `billf/convex/adapter` @ `7973dce6`)

- `skipruntime-ts/adapters/convex/src/index.ts:1-387`: `ConvexExternalService`
  over `ConvexSubscriber = Pick<ConvexClient,"onUpdate"|"close">` (`:63`),
  `TypedConvexReactiveResource` with `argsFromParams(params,scope)` (`:28-38`),
  `defineConvexReactiveResource` (`:53-60`), `diffSnapshot` via
  `isDeepStrictEqual` (`:133-163`), capped resubscribe
  (`maxResubscribeAttempts=5`, `resubscribeBackoffMs=100`, `:70-91`,
  `:274-305`), `createAuthenticatedConvexClient` (`:99-106`),
  `assertSkipJson` rejecting `bigint`/`bytes` (`:109-131`).
- Transport: full-snapshot `onUpdate` → one `callbacks.update` batch per
  re-evaluation. O(n) diff per snapshot. Restart = fresh `isInitial:true`.
- Serving: `server/src/rest.ts` control (`POST /v1/streams/:resource`) +
  streaming (`GET /v1/streams/:uuid`, SSE `init`/`update` + watermark). No auth
  in either port — gateway required.

## Gap resolutions

1. Lower-level protocol: stay in TypeScript. The sync wire
   (`crates/convex/sync_types/src/types/mod.rs:305-387`,
   `npm-packages/convex/src/browser/sync/protocol.ts`) carries whole
   `QueryUpdated.value`, no delta variant; a Rust client at the same layer
   sees the same shape. A WS `/api/sync` peer (`deployment_url` → `api/sync`,
   `crates/convex/src/client/mod.rs:416-427`) buys protocol control
   (base-version checks, `TransitionChunk` reassembly per
   `web_socket_manager.ts:300-347`) but not deltas. Recommend: keep
   `onUpdate` for v2; add WS peer only if chunk/ownership profiling demands it.
2. Durable replay: not available. `Transition.endVersion.ts` /
   `maxObservedTimestamp` is a causal watermark, not a query-replay cursor;
   adapter correctly re-snapshots. Document as constraint; do not build resume
   on it.
3. Write path: unchanged — mutations go to Convex, never through Skip inputs.
   `update(collection,entries)` stays unused for Convex-sourced collections.
4. Large queries: partition at the query layer. One bounded query per
   tenant/partition via `argsFromParams(params,scope)`; immutable partition
   key; intra-partition aggregates only. Treat limit-truncation as failure
   (indistinguishable from mass delete), fail loudly.
5. Auth: `createAuthenticatedConvexClient` + per-adapter frozen
   `ConvexServiceScope{tenantId}` (`:21,:203-208`); query must verify caller
   identity may read that tenant; control port behind gateway (mint + DELETE
   on logout/expiry; UUID is bearer).

## Bounded-query contract (new)

- `getKey` returns non-empty string, stable across snapshots; duplicates throw.
- Rows pass `assertSkipJson`; `int64`/`bytes` need caller-side encoders.
- `argsFromParams` injects scope tenant, rejects caller-supplied tenant.
- Deletion = `[key,[]]`; capped/ordered queries are out of scope for the
  adapter (use journal-backed pagination at the Convex layer instead).

## Acceptance

- TS signatures for resource, scope, logger, resubscribe options frozen.
- Sequence diagram: mutation → rerun → `onUpdate` → diff → `update(batch)` →
  map/reduce → SSE.
- Failure matrix: bootstrap reject, mid-stream reject, max-attempts inert,
  shutdown drain, restart-initial — all covered by adapter tests.

## Addendum (sub-direction 1a mandate)

The recommendation above ("keep `onUpdate`, WS peer only on profiling
demand") is superseded where 1a applies: 1a requires speaking `/api/sync`
directly with no backend changes. The bounded-query contract, auth/scope
shape, and failure matrix here still hold; the transport choice does not.
Full wire→Skip mapping (lifecycle, versions, chunks, per-`query_id` diffing,
demand-driven query set, PoC vehicle, correctness bar) is published in
`research-sync-protocol-skip-mapping.md` — read that instead of re-deriving
from this doc's gap-resolution §1.

# X-Verification Report (2026-09-12)

Verify-only pass over the 53-file corpus (`git diff --name-only
origin/main...`). ~230 distinct `file:line` citations resolved against
source at HEAD, plus ~60 quoted code blocks, a cross-doc consistency
matrix, plan↔research traceability, and evidence↔doc sync. No research or
plan doc was edited in this pass. Severity: **wrong** (never-accurate) /
**moved** (drifted, new location recorded) / **stale** (true once or
unverifiable detail) / **contradictory** (docs disagree) / **unverifiable**
(proposals, pedagogy, absence claims).

## 1. Wrong (never-accurate — fix the citation, not the line)

- Wire-checklist `web_socket_manager.ts:114-149` as backoff computation:
  that range is the `serverDisconnectErrors` table; computation is at
  `:869-883`. Archeology: same layout since at least tag `696941bf6`
  (Mar 2026) — never co-located. Recommend symbolic pin (table name +
  function name, no lines).
- Index-metadata bare paths `bootstrap_model/index/mod.rs:32`,
  `index_registry.rs:365`, `index_registry.rs:655-698`,
  `bootstrap_model/index.rs:*`: no `crates/database/src/index_registry.rs`
  or `crates/database/src/bootstrap_model/index/mod.rs` ever existed
  (no deletion in history). Actual homes: `crates/indexing/src/
  index_registry.rs`, `crates/common/src/bootstrap_model/index/`,
  `crates/database/src/bootstrap_model/index.rs`. Bare `index_registry.rs`
  is ambiguous between two real files — always carry the crate segment.
  Recommend symbolic pins (`require_enabled` in `crates/indexing/src/
  index_registry.rs`, `stable_index_name` in `crates/database/src/
  bootstrap_model/index.rs`, etc.).
- Composition `isolate/.../udf/query_impl.ts` (§2.3 heading): no such file.
  Quoted TS is `npm-packages/convex/src/server/impl/query_impl.ts`.
- Reactivity `subscribe_and_wait_for_subscription_invalidation`
  (`database.rs:2084-2097` quotes): actual name is
  `subscribe_and_wait_for_invalidation` (`:2090-2099`); quoted signature
  `(current_ts: Token)` and body mix two functions. Likewise
  `query/mod.rs:139-200` as "fresh traversal" — that range holds
  `DeveloperQuery`/`TableFilter`/`ResolvedQuery` structs, not execution.
- Wire-checklist details: `clientTs: Date.now()` (actual
  `monotonicMillis()` via `web_socket_manager.ts:389-393` spread);
  `sessionId` at `:158-164` (type-only; actual `client.ts:273,385`,
  `session.ts:1-2`); AuthError "fatal restart" overstates (Rust returns
  `Err` for both AuthError `:684-696` and FatalError `:697-700`);
  `Event{event_type,event}` at `:205-212` (variant at `:205`, fields in
  `struct ClientEvent :209-212`).
- Index-metadata `enable` rejects Backfilling/Enabled but does not check
  `staged:false` explicitly (`:192-201`); `schemas/mod.rs:355-401` does
  not itself demonstrate no-fetch (inferred from validator path).
- Push-seam `:741-755` cited without a file (unresolvable);
  `forward_http_action_stream` not found under `local_backend/src/*.rs`;
  `data_sync.rs` bare (actual `crates/table_iteration/...`).
- Atomic-write `needGC :1409-1411` is the definition; enforcement is at
  `:491-492`.
- Agent error (not a doc bug): 1a-answers `http/mod.rs` flagged missing —
  the checker searched `crates/local_backend/src/http/`; the file is
  `crates/common/src/http/mod.rs` (`from_path_param` at `:968`). Citation
  stands.

## 2. Moved (drifted — new locations recorded)

- `query_impl.ts` `.next()`: cited 264-272, actual 255-272.
- `mod.rs` source match: cited 412-448, actual 412-449.
- `assertSkipJson`: cited 108-131, actual 109-131.
- Mapping `client/mod.rs:416-427`, actual 416-426; `QueryRemoved`
  320-323 → 320-322; `json.rs` 549-551 → 549-550.
- `syscall.rs:232-238` bare → `crates/isolate/src/environment/udf/
  syscall.rs:234`.
- `server/src/rest.ts` bare → `skipruntime-ts/server/src/rest.ts`.
- `FFI.sk` → `skipruntime-ts/skiplang/ffi/src/FFI.sk:135-156`;
  `tests.ts:397-407` → `skipruntime-ts/tests/src/tests.ts`.
- `pagination.ts` bare is ambiguous (`server/pagination.ts` 208 lines vs
  `browser/sync/pagination.ts` 50 lines) — always qualify.
- All index-metadata bare paths resolve as listed in §1 (content verified
  at the `crates/...` homes).
- Composition `query.ts:29-68` is narrow (interface spans 29-105);
  `database.ts:211-240` holds doc-comments only, no code example.

## 3. Stale / imprecise (true content, loose pin)

- Data-sync `self-host 2d` unverifiable in `knobs.rs:636-659` (4m/14d
  verified); cursor-ahead vs expired code distinction omitted
  (`data_sync.rs:455-461` vs `streaming_export.rs:530-544`); "3d window"
  lives at `local_backend:...:373-374,424-426,460-464`, not the cited
  progress range.
- Engine `LazyCollection` shapes simplified (`(V & DepSafe)[]`,
  `{ifNone?,ifMany?}`); streams routes omitted from bibliography;
  `~3GB` / `~100 files` size claims unverifiable.
- Externals-adapter quote blocks elide generics/`DepSafe`/docs throughout;
  `ServiceInstance` conflates core `unsubscribe(id)` with REST close;
  example bodies not diffed (files exist).
- Grounding "no Rust chunk reassembly found (maybe tungstenite handles
  it)": Rust affirmatively rejects `TransitionChunk`
  (`base_client:720-724`) — uncertainty is resolved, dossier predates it.
- Spike-comparison `TxMetricsJson`/`log_index_range`/`TS_*`/timestamps all
  verified; `TS_*` counters are test-only (harness keeps own counts).

## 4. Contradictory (exactly one)

- Mapping doc §2 row says `QueryFailed` → "drop last value, re-subscribe";
  the 1a plan (R5), 1a-review-answers, and wire-checklist all say
  freeze-at-last-good + stale indicator. Mapping predates the freeze
  decision and is stale on this row; review-answers is authoritative.

## 5. Unverifiable by construction (correctly so)

- Proposals with no source counterpart: `QueryPatched`, `QueryOperator::Skip`
  + `skip.rs` + JSON arms, wire-JSON examples, A/B/C snippets, example
  services. Flagged as proposals in text — no action.
- Pedagogical examples (SQL tweets, `CountTweets`), summary syntheses,
  line counts (`~1000`), absence claims (`no updateMany` — consistent
  with repo search).
- Paraphrase-presented-as-quote pattern (generics/`DepSafe`/comments
  elided, `...` bodies) across composition/engine/externals docs:
  content accurate, attribution loose. Recommend marking elided quotes
  explicitly rather than re-verifying each.

## 6. Traceability (D) and index/handoff (F)

- Orphans confirmed intentional: `client-v2` (transport superseded, sections
  still referenced by mapping doc; retagged `superseded-fallback`), `build-slices` (historical),
  `spike-comparison` + `source-state` (uncited by the four spike plans, cited only by the shared-prerequisites `1159` plan; usage maps added
  to both docs this cycle).
- Plans' Sources entries resolve (landed): 1a cites `research-sync-protocol-
  skip-mapping.md` (`1509:220`); Dir-2 cites `research-index-id-metadata.md` and
  `research-native-operator-spec.md` (`1702:267-268`); 1b cites page-topology (`1843:220`); 1c cites data-sync-source + push-seam (`1854:264-265`). No open hygiene gaps.
- README index: zero `Note` flags; poc-vehicle correctly under Direction 2
  with pointers; `shared inputs` heading accurate for atomic-write.
- Handoff SHAs/branch claims and overview direction summaries match current
  state; overview "Next Steps" TODOs remain open by design.

## 7. Evidence sync (E)

Phase 1 dossiers predate this cycle's fixes. Stale verdicts: reactivity
(reads.rs pin — fixed), composition (queryStreamNext — fixed),
data-sync-source (prefix style — fixed), spike-comparison (per-spike
mapping — added), poc-vehicle (direction — narrowed with pointers),
native-operator-spec (MAX_QUERY_OPERATORS — fixed to 256).
Refreshed append-only under `evidence/` (Phase 1 records preserved).

## 8. Pin-style recommendations

Prefer symbolic pins (`function`/`struct`+`impl`/`trait` + file, quoted
signature as anchor) for: anything in `web_socket_manager.ts`,
`local_state.ts`, `bootstrap_model/`, `index_registry.rs`, and any range
inside a function body over 30 lines. Keep exact pins for: enum/wire
structs (`sync_types`), constants, `knobs.rs` values, short functions.

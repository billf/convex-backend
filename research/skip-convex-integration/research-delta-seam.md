# Delta seam ranking (reactivity plug-in order)

Augments `research-convex-reactivity.md` §4 (plug-in points A–D) and §7
(layers). Does not repeat the read-set/subscription/OCC exposition. Gives the
build order and the one seam to avoid.

## Central constraint (from existing notes)

Convex reactivity is coarse invalidation + full re-run
(`Subscription::wait_for_invalidation()->Option<Timestamp>`; caller
re-executes). Skip gives per-key `add`/`remove` O(1) deltas with `null` =
fall back to full recompute. Integration must therefore attach Skip where a
miss is just a re-query, never on the commit path.

## Ranked seams (best first)

1. Query-result / index-cache maintenance. Generalize
   `write_log.rs:fast_forward_index_cache` (today single-tx reuse) plus
   `TimestampedIndexCache` into a Skip-backed materialized view
   (`EagerCollection` with `map`/`reduce`/`merge` deps). Failure = cache miss
   → re-query. No correctness risk to commit ordering.
2. Subscription invalidation feed. Feed externalized
   `Token{read_set,ts}` (`database/src/token.rs:17-20`) + `LogReader::
   refresh_token` / `writes_overlap_by_index` (`reads.rs:233-306`) into Skip
   as input frontiers. Optionally back `SubscriptionTrait::extend_validity`
   (`application/src/api.rs:614-668`) with a Skip-consulting
   `SubscriptionClient`. Keep `processed_ts` + retention semantics in
   `SubscriptionManager::advance_log` (`subscription.rs:492-660`); replace
   only the `to_notify` computation.
3. Index maintenance (backfill + live). `database_index_workers` +
   `search_worker` step functions keep their loops; Skip `mapReduce` maintains
   secondary/aggregate indexes after the initial `backfill_from_ts` seed. Must
   preserve `DatabaseIndexState` transitions exactly — higher risk than 1–2.
4. Do not touch: OCC validation (`committer.rs:pre_validate_batch`,
   `write_log.rs:is_stale`) and persistence
   (`track_and_write_to_persistence`, `WriteBatcher`, retention). Must stay
   synchronous, total-ordered, false-positive-free; Skip latency + `remove →
   null` semantics are incompatible.

## Wire delta sketch (backend-side change, needs backend owners)

Protocol today has no delta variant: `StateModification::QueryUpdated`
carries whole `value`, deduped only by result hash (`sync/src/state.rs`).
To send Skip deltas, add `StateModification::QueryPatched` + JSON arms +
TS `StateModification` union + `assembleTransition` passthrough; keep
`QueryRemoved`/`QueryFailed` unchanged. Chunking
(`local_backend/src/subs/mod.rs:maybe_split_transition`) already covers large
snapshots in the interim. Client-v2 ships on snapshots regardless.

## Acceptance

- Seam table above with file:line evidence; explicit OCC/persistence
  exclusion with rationale.
- `Token` externalization shape (intervals + ts) defined or deferred with
  reason.
- `QueryPatched` schema + compat/fallback notes, or deferral with reason.

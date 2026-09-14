---
title: Index and v.id metadata
type: research-note
status: active
direction: 2
date: 2026-09-11
---

# Index + v.id metadata (Direction 2 `incremental-materialized-cache-implicit-base-index-views` (D2 R17) through `incremental-materialized-cache-reverse-join-index` (D2 R22), `incremental-materialized-cache-preregistered-room-message-feed` (D2 R7))

Which existing metadata drives Skip lookups and joins without coupling to
unstable internals. Stable-to-couple vs internal-do-not-parse split, plus
lifecycle validation and dangling-reference behavior.

## Stable API (couple to these)

- Declared query contract: `fullTableScan()` (`server/query.ts:41`),
  `withIndex(name, range?)` (`:60-68`), `withSearchIndex` (`:89-98`).
- Point reads: `db.get(table, id)` → value or `null`
  (`server/database.ts:30-33,98-100`); `normalizeId` checks the table tag
  only, never existence (`:62-76`).
- `v.id(table)` wire form `{type:"id", tableName}`
  (`values/validators.ts:67-100`); `Validator::Id(TableName)`
  (`common/src/schemas/validator.rs:58-59`); transitive `foreign_keys()`
  (`:585-624`, `schemas/mod.rs:731-738`, `ObjectValidator::foreign_keys()`).
- Index names: `IndexName = TableName`, `TabletIndexName = TabletId`,
  `StableIndexName::{Physical,Virtual,Missing}`, `IndexDiff` shape,
  `by_id/by_creation_time()` (`common/src/types/index.rs:105-304`).
- `IndexedFields::by_id() = []`, `creation_time() = [_creationTime]`
  (`crates/common/src/bootstrap_model/index/database_index/indexed_fields.rs:38-46`); system appends `_id`.
- Index state: `Backfilling{staged} | Backfilled{staged} | Enabled`
  (`crates/common/src/bootstrap_model/index/database_index/index_state.rs:19-27`); `is_staged/is_enabled/is_backfilled/same_spec`
  (`crates/common/src/bootstrap_model/index/index_config.rs:65-148`); `_index` table (`crates/database/src/bootstrap_model/index.rs:32`).
- Live schema source: Active row of `_schemas`
  (`bootstrap_model/schema/mod.rs:48-67,194-204,295-322`); `get_by_state`,
  `get_validated_or_active`, `apply()`; `transaction.rs:849-868`
  `get_schema_by_state` with read dependency.

## Internal (do not parse / branch on)

`IndexKeyBytes(Vec<u8>)` — explicitly unparsed, encoding driver-dependent
(`common/src/index.rs:79-95,132-145`). `TabletIndexName ↔ IndexName`
translation via table mapping (`Missing` for absent tables,
`bootstrap_model/index.rs:811-854`). `IndexId`/`PersistenceIndexId`,
`DatabaseIndexUpdate/Value::{Deleted,NonClustered}`, `Serialized*` forms.

## Full scan, system indexes, enabled validation

Full scan desugars to `by_creation_time` (`database/src/query/mod.rs:303-322`;
`_index` uses `by_id` instead). New tables get both as `Enabled`-when-empty
(`bootstrap_model/table.rs:565-577`); system tables likewise
(`transaction.rs:976-986`); system indexes are immutable
(`bootstrap_model/index.rs:111,174-177`, `crates/indexing/src/index_registry.rs:365`).
Named `withIndex` must resolve to enabled metadata
(`query/mod.rs:316-322`, `bootstrap_model/index.rs:703-746`,
`transaction_index.rs:610-621`, `crates/indexing/src/index_registry.rs:655-698`); read deps on
`_index.by_id` keep invalidation exact (`:623-643`, `:908-931`).

## Staged/disabled lifecycle

`disable: Enabled → Backfilled{staged:true}` (`:362-419`);
`enable: Backfilled{staged:false} → Enabled`, rejecting Backfilling/Enabled
(`:169-240`). `get_index_diff` compares spec + staged flag
(`:513-651`): Identical / Enabled / Disabled / Replaced (field/order change)
 / dropped. Registration (static): check `DatabaseSchema.tables[t]`
descriptors + staged flags + `IndexedFields` equality/order. Activation
(live): `stable_index_name != Missing` + `require_enabled_*` success;
backfilling vs staged errors distinguish retry vs disabled
(`crates/database/src/bootstrap_model/index.rs:1136-1165` `indexes_ready`). Ongoing: depend on `_index`
(`take_indexes_dependency`) or poll diffs; Replaced/dropped/disabled →
rebuild/pause/fail-closed.

## v.id joins + dangling behavior

`v.id` validation is value-check only: decode `DeveloperDocumentId`,
map table number → name, compare (`validator.rs:117-145`); enforcement
(`schemas/mod.rs:355-401,648-671`) never fetches. Dangling IDs pass.
Native point read = singleton `by_id` range; miss → `None`
(`transaction.rs:603-627,1098-1160`); unknown table → `None`
(`crates/database/src/bootstrap_model/user_facing.rs:78-112`, `transaction.rs:619-622`). So: forward join miss =
`null`/absent (mirror `db.get`), reverse join = empty set, no cascade; table
delete blocked only by schema (`ReferencedTableCannotBeDeleted`,
`schemas/mod.rs:80-112,414-432`).

Deployed-schema graph source: Active `_schemas` row → `DatabaseSchema`
→ per-table `document_type: Union(ObjectValidator)` → transitive
`foreign_keys()` for forward edges; invert for reverse edges — without
re-implementing validator semantics.

## Change feed fitness (no key parsing)

Both payloads derive from one commit (`committer.rs:1030-1086`): full
`OrderedDocumentWrites` (persistence/OCC/snapshot) and `IndexKeyWrites`
(log). For Skip deps use `document_id + TabletIndexName + old/new presence
+ new_document` — never decode `IndexKeyBytes`. `by_id` base → singleton
writes + id; `by_creation_time`/full-scan → per-table writes in commit
order; named lookups → that index's writes; forward join → target `by_id`
write; reverse join → child foreign-key index writes. Resolve
`TabletIndexName → (table, descriptor, IndexedFields)` via enabled metadata
at activation. Limits: retention-bounded (`purged_ts`, `OutOfRetention`),
pending-own-writes overlay is separate (`transaction_index.rs:154-333`).

## Acceptance

Stable-vs-internal split recorded; registration/activation/ongoing
validation named; dangling semantics mirrored; feed mapping uses ids +
presence, never key bytes.

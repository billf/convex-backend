---
title: Static fixture indexes vs dynamic index lifecycle
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md
---

# Static fixture indexes vs Direction 2 dynamic lifecycle

All directions start from the same declared application indexes. Only
Direction 2 tests eligibility/rebuild behavior when an index is staged,
removed, or incompatible. This split avoids implying 1a/1b/1c must test
backend index lifecycle while preserving Direction 2's requirement
(D2 R17-R22, AE6 — `...1702...:114-122,225-229`).

## Static set (every direction assumes present + enabled)

- Contract indexes (`...1159...:90`): `memberships.by_room_user[room,user]`,
  `messages.by_room[room]`, `likes.by_message[message]`.
- Built-ins, always in contract (`...1702...:39,114`;
  `research-index-id-metadata.md:49-57`): `by_id` + `by_creation_time` per
  table; full scan desugars to `by_creation_time`; new tables get both
  `Enabled`-when-empty; named `withIndex` must resolve to enabled metadata.

1a/1b/1c contract: indexes present and enabled, no lifecycle testing. 1a
uses plain per-table queries (`...1509...:67-69`); 1b uses `messages.by_room`
+ reactive pagination (`...1843...:49,220`); 1c fixes the five-table selection
(R2 `...1854...:70`; fixture adds via U5 `...1854...:600-601`).

## Dynamic lifecycle (Direction 2 only)

State machine (`research-index-id-metadata.md:59-71`): disable
`Enabled → Backfilled{staged:true}`; enable rejects Backfilling/Enabled;
`get_index_diff` Identical/Enabled/Disabled/Replaced/dropped; registration =
static descriptor + staged + `IndexedFields` check; activation =
`stable_index_name != Missing` + `require_enabled_*`; ongoing via `_index`
dependency or diff poll → rebuild/pause/fail-closed.

D2 gates: R17 implicit `by_id`/`by_creation_time` base views for the five
tables only; R18 every extra lookup backed by an enabled app index; R19
missing/staged/disabled/removed/incompatible → ineligible until rebuilt;
R20 forward `v.id` → `by_id` edge; R21 missing-target parity (no
referential-integrity reading); R22 reverse join requires an enabled index
on the referencing field. AE6 covers R14/R17-R19/R22: a staged/removed/
disabled/incompatible index means no serve under a stale contract, with the
reason named in metrics; F1 gates bootstrap on activation
(`...1702...:175-180`).

## Forward vs reverse join index rules

Forward edges derive from validated `v.id("targetTable")` fields to target
`by_id` materializations (R20); dangling targets keep native
missing-behavior (R21). Reverse joins need an enabled application index on
the referencing ID field (R22). Stable-vs-internal split that makes this
safe to couple to: `research-index-id-metadata.md:15-37` (stable `withIndex`
contract, `db.get` value-or-null, `v.id` wire form; internal do-not-parse
`IndexKeyBytes`/`IndexId`/tablet translation).

## Anti-confusion table (not index lifecycle)

| Looks like index lifecycle | Actually is | Why distinct |
|---|---|---|
| 1b `InvalidCursor` → full reset (`research-1b-page-topology.md:28-31`; 1b R10) | query-cursor lifecycle | cursor fingerprint mismatch, not `_index` staged/disabled |
| 1c table replacement / truncation (R6-R7 `...1854...:76-77`; AE4) | Data Sync lifecycle | generation swap, not index enablement |
| 1a `QueryFailed` vs `QueryRemoved` vs not-yet-loaded (`...1509...:61`) | query state | subscription state, not index state |

## Open questions

- Should 1b's `InvalidCursor`-reset and 1c's replacement paths assert
  "indexes still enabled" on rebuild, or is that D2-only?
- Does 1b's page query need any index beyond `by_room` (user/like lookups
  held constant per `...1843...:211`)?
- Where does the `_index`-read-dependency / `indexes_ready` check
  (`research-index-id-metadata.md:56-57,69`) live for D2 — registration only
  or ongoing poll?

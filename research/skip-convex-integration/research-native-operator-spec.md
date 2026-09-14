---
title: Native Skip Operator Spec
type: research-note
status: active
direction: 2
date: 2026-09-11
url: https://github.com/convex-dev/convex-backend/tree/main/research/skip-convex-integration/research-native-operator-spec.md
---

# Native Skip operator spec (Track 2 construction spec)

Augments `research-convex-query-composition.md` §4 (Options A/B/C) and §6
(MVP vs deep). Does not repeat the `Query`/`QueryStream`/syscall exposition.
Picks one recommended path with rejection reasons.

## Recommendation: Option A (composable operator), MVP first

- MVP (no Rust changes): call Skip-authored mappers/reducers from user JS
  after `collect()`. Ships immediately; pays full-scan cost.
- Deep (this spec): `QueryOperator::SkipFilter` / `SkipMap` as first-class
  pipeline operators so Skip code runs server-side interleaved with
  index-range prefetch and `Limit` early termination.

Reject B (separate top-level Skip UDF type) for v1: new `UdfType` +
`registration_impl` + isolate `analyze`/`strings` + runner + proto surface,
and no composition with `.filter()`/`.limit()`. Reject C as a variant of A
with a less explicit wire shape.

## Touch list (all exhaustive matches — compiler guides)

TS (`npm-packages/convex/src/server/`):
- `impl/query_impl.ts:24` extend `QueryOperator` union (`{skip:{...}}`);
  add `QueryImpl.skipX()` mirroring `filter:225-241`/`limit:243-248`,
  respecting `MAX_QUERY_OPERATORS = 256` (`query_impl.ts:22`,
  `crates/common/src/query.rs:912`); `server/query.ts` interface addition.

Rust:
- `crates/common/src/query.rs:899-904` add variant + constructor;
  `crates/common/src/json/query.rs` add `JsonQueryOperator::Skip` + both
  `TryFrom` arms; `crates/database/src/query/mod.rs:450-462` construction
  arm, `:693-698` `QueryNode::Skip` variant, `:700-768` delegate all 7
  `QueryStream` methods; new `crates/database/src/query/skip.rs` modeled on
  `filter.rs:28-85` / `limit.rs:23-83`.
- Syscall unchanged: `syscall.rs:232-238` (`Query::try_from`) and
  `async_syscall.rs` page/batch paths carry the variant automatically;
  fingerprint covers it.

## Wire example

```json
{"source": {"type": "IndexRange", "indexName": "tasks.by_user", "range": [],
  "order": null},
 "operators": [{"skip": {"op": "filter", "codeRef": "<sha>"}},
               {"limit": 100}]}
```

Skip code itself ships out of band (bundle hash / registry ref); the operator
carries only the reference + params so the query descriptor stays small and
fingerprint-stable.

## Acceptance

- Single recommended option with rejection reasons recorded.
- File:line checklist above; wire example is a proposed shape (the `Skip` variant exists in neither `query_impl.ts:24` nor `query.rs:899` yet) — round-trips TS→Rust once both enums are extended.
- `cargo build -p convex-common -p convex-database` + query syscalls green;
  exhaustive-match errors treated as the touch-point oracle.

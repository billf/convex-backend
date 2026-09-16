---
title: Direction 2 Cross-Check Audit - Findings Memo
type: research-note
status: active
date: 2026-09-16
audits: docs/plans/2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md
---

# Direction 2 Cross-Check Audit - Findings Memo

## Executive verdict

**Ready with explicit prerequisites.** The Node-child, combined-input,
seed-and-tail, and five-table vehicle choices are supported by the inspected
code and research. Implementation may begin, but the work must treat the
three implementation-critical items under Required clarifications as acceptance
gates for the affected units. The host-surface wording is a
documentation-integrity correction, not an implementation gate. In particular,
the uncommitted `read_many` / version-expiry proposal is
not a settled runtime capability, and native-oracle comparison is unsafe until
the Convex-to-Skip value encoding is specified and tested. The version-gate
units additionally require a time-boxed feasibility proof of the host-owned
serialized read/arm sequence before they start; if the interleaving and expiry
tests fail, either descope version-gating or block on upstream `read_many`.

| Spike-unit readiness | Audit result |
|---|---|
| Host package and registration/supervision | May start in parallel, following the spike plan's protocol-agreement constraint. The host package must close notifier ordering before it supports atomic-read claims. |
| Feed lifecycle, version gate, and sync opt-in | Follow the declared predecessor sequence. The version-gate unit cannot start its accelerated path until the serialized read/arm feasibility proof passes. |
| Local-backend wiring and proof harness | Follow the declared predecessor sequence and inherit the value-boundary and lifecycle gates. |
| Scaling study | Runs last and requires the resource-bound test so retained-resource growth is not reported as graph-state cost. |

This audit does not alter the spike plan's execution order.

This is a read-only audit. It does not change the spike plan, its research
inputs, or code.

## Audit provenance

| Repository | Resolved revision | Ref | Dirty state at inspection |
|---|---|---|---|
| convex-backend | `ed337730522fa9e15216d773e69eb70959937546` | `skip-incremental-materialized-cache-plan` | `docs/plans/2026-09-15-1434-chore-direction2-crosscheck-audit-plan.md` and `docs/plans/IDENTIFIER-MAP.md` modified; neither was used as implementation evidence. |
| skip | `7ba68ef38dbc0f48afc3bde95cff6bc98aafbb78` | `billf/convex/adapter` | clean |

The npm registry resolves `@skipruntime/core@0.0.23` to
`core-0.0.23.tgz`; the planned registry path is therefore available. `skargo`
is not on `PATH`; the Skip checkout contains its source and the wasm package
build script, but this fallback was not built or validated. It is a fallback
prerequisite only if registry artifacts cease to be usable.

## Evidence key

| Key | Direct evidence |
|---|---|
| E1 | `skip:skipruntime-ts/core/src/index.ts:772-811` accepts one collection, forks, awaits update handles, then merges; `:1398-1422` gives transactional service initialization. |
| E2 | `skip:examples/convex_reactive/skip/service.ts:34-49,68-86,151-161` demonstrates one tagged input split into collections and a reducer with inverse removal. |
| E3 | `crates/database/src/write_log.rs:331-356` enforces increasing timestamps and appends per-index writes at one timestamp; `:359-378` waits for progress; `:380-419` trims retained entries. |
| E4 | `crates/database/src/snapshot_manager.rs:558-676` supplies a repeatable latest timestamp and rejects snapshots outside its readable window. |
| E5 | `crates/database/src/subscription.rs:219-285,643-656` coordinates retention after all subscription managers process a timestamp. |
| E6 | `crates/sync/src/worker.rs:938-1054,1257-1320` builds query updates and publishes a single versioned Transition. |
| E7 | `skip:skipruntime-ts/adapters/convex/src/index.ts:108-131` rejects bigint and binary values; `:244-365` serializes adapter delivery and fences replacement generations. |
| E8 | `skip:docs/research/research-dir2-host-requirements.md:21-71` and `skip:docs/research/research-dir2-skip-evidence.md:31-245` state the host contract, provenance taxonomy, and its limitations. |
| E9 | `research/skip-convex-integration/semantic-vectors-v1.md:17-22,33-123` fixes the five-table output contract and V1-V6 corpus. |
| E10 | `research/skip-convex-integration/research-publication-state-semantics.md:11-63` separates runtime `Current` from harness-only `comparison-ready`. |

In this memo, `skip:` prefixes a path in the Skip repository pinned in Audit
provenance; unprefixed paths are in convex-backend.

## Traceability matrix

Verdicts: **aligned** means the stated design agrees with inspected evidence;
**underspecified** means the design direction is supported but lacks a required
contract or test; **contradicted** identifies an inaccurate claim; and
**unverified** identifies a premise not committed or not established by the
inspected sources. An assumption class appears only where an evidence path is
absent or incomplete.

### Requirements

| Stable identifier | Plan claim / supporting research | Evidence | Verdict |
|---|---|---|---|
| `incremental-materialized-cache-committed-row-change-input` | Ordered post-commit input; host requirements call for ts-grouped committed rows. | E3, E8 | aligned |
| `incremental-materialized-cache-transaction-atomic-visibility` | One commit becomes one atomic combined-domain apply. | E1, E3, E8 | aligned |
| `incremental-materialized-cache-incremental-maintained-operators` | Persistent mapper/reducer graph with inverse removal. | E2, E8 | aligned |
| `incremental-materialized-cache-scaling-instrumentation` | Count logical work by maintained stage. | E2, E8 | aligned |
| `incremental-materialized-cache-authoritative-convex-source` | Convex remains authoritative; Skip is derived. | E8 | aligned — backend policy |
| `incremental-materialized-cache-consistent-bootstrap-recovery` | Seed at a repeatable snapshot then tail to a fence. | E3, E4, E8 | aligned |
| `incremental-materialized-cache-preregistered-room-message-feed` | One fixed five-table room feed. | E8, E9 | aligned |
| `incremental-materialized-cache-preregistered-view-only` | No generated or just-in-time views. | E8 | aligned — backend policy |
| `incremental-materialized-cache-accelerated-handshake` | Opt-in carries only acceleration state; query values stay Convex values. | E6, E8 | underspecified — protocol field and compatibility test belong to `incremental-materialized-cache-u-sync-protocol-opt-in`. |
| `incremental-materialized-cache-required-version-consistency` | Wait for the causal watermark or fall back. | E4, E6, E8 | underspecified — depends on the uncommitted host read contract described below. |
| `incremental-materialized-cache-native-fallback` | Native result on unavailable, unhealthy, incorrect, or deadline-lost acceleration. | E6, E8, E10 | aligned |
| `incremental-materialized-cache-fallback-metrics` | Attribute every fallback and progress state. | E8, E10 | aligned — backend policy requiring implementation coverage |
| `incremental-materialized-cache-independent-correctness-check` | Same-version native oracle after four checkpoint gates. | E9, E10 | underspecified — JSON encoding must be closed first. |
| `incremental-materialized-cache-idiomatic-convex-baseline` | Compare the strongest fitting native baseline. | E8 | aligned — evaluation policy |
| `incremental-materialized-cache-scaling-report` | Measure unrelated-data and fan-out axes, not just speed. | E8 | aligned — evaluation policy |
| `incremental-materialized-cache-native-surface-unchanged` | Disabled/bypassed acceleration leaves ordinary clients unchanged. | E6, E8 | aligned |
| `incremental-materialized-cache-implicit-base-index-views` | Materialize only the five tables' built-in bases. | E8, E9 | aligned |
| `incremental-materialized-cache-indexed-maintained-lookups` | Additional lookups require enabled application indexes. | E8, E9 | aligned |
| `incremental-materialized-cache-index-eligibility-validation` | Invalid index state prevents accelerated serving. | E8 | aligned — backend policy, test at activation and tail revalidation |
| `incremental-materialized-cache-validated-id-join-edges` | `v.id` supplies scoped forward join metadata. | E8 | aligned — external schema premise to validate against snapshots |
| `incremental-materialized-cache-missing-target-join-semantics` | Missing targets preserve native null/missing behavior. | E8, E9 | aligned |
| `incremental-materialized-cache-reverse-join-index` | Reverse fan-out requires a referencing-field index. | E8, E9 | aligned |

### Acceptance examples

| Stable identifier | Plan claim / supporting research | Evidence | Verdict |
|---|---|---|---|
| `incremental-materialized-cache-atomic-multi-table-update` | Membership plus like has no torn observation. | E1, E3, E9 | underspecified — merge-versus-notifier ordering and re-entrant read behavior are not established by E1. |
| `incremental-materialized-cache-version-gated-read` | Result is at least the requested version. | E4, E6, E8 | unverified — `read_many` is working-tree WIP, not committed Skip code. |
| `incremental-materialized-cache-silent-observable-fallback` | Failure uses native result with a reason. | E6, E8, E10 | aligned |
| `incremental-materialized-cache-scaling-demonstration` | Curves distinguish delta work, seed/rebuild, and state cost. | E8 | aligned — evaluation policy |
| `incremental-materialized-cache-restart-without-stale-publication` | Before/after-snapshot writes survive fencing. | E3, E4, E8 | aligned |
| `incremental-materialized-cache-index-lifecycle-gate` | Staged or changed index blocks stale serve. | E8 | aligned — backend policy requiring a schema/index mutation test |
| `incremental-materialized-cache-dangling-typed-reference` | Missing sender remains nullable and matches native. | E8, E9 | aligned |
| `incremental-materialized-cache-shared-semantic-corpus` | V1-V6 define canonical output, including 50th/51st tie behavior. | E9 | aligned |

### Key technical decisions

| Stable identifier | Plan claim / supporting research | Evidence | Verdict |
|---|---|---|---|
| `incremental-materialized-cache-ktd-node-child-host` | Backend-supervised Node child; plan says no Rust-callable engine exists. | E8 | contradicted in wording — Node is the supported demonstrated surface, but Skip exports an unsupported C ABI; do not claim direct Rust integration is impossible. |
| `incremental-materialized-cache-ktd-write-log-tail-feed` | Tail write log and regroup by commit timestamp. | E3, E5, E8 | aligned |
| `incremental-materialized-cache-ktd-combined-input-atomic-apply` | One `ServiceInstance.update` for one combined collection. | E1, E2, E8 | aligned, subject to the `incremental-materialized-cache-atomic-multi-table-update` notifier-order test. |
| `incremental-materialized-cache-ktd-seed-then-tail-rebuild` | Fresh generation, seed, fence, then serve; no persistence. | E1, E3, E4, E8 | aligned |
| `incremental-materialized-cache-ktd-eligibility-validation` | Validate declaration against snapshot registry/schema and revalidate from tail. | E8 | aligned — backend policy / external metadata premise |
| `incremental-materialized-cache-ktd-lifecycle-states-fallback-reasons` | Inactive/Rebuilding/Serving/Unhealthy/Ineligible and attributed fallback. | E8, E10 | aligned |
| `incremental-materialized-cache-ktd-view-backed-version-pinned-reads` | Serialized host read pins a Transition version and subscription freshness. | E1, E6, E8 | unverified — proposed `read_many`, expiry, and generation invalidation are uncommitted WIP; public read/subscription primitives have a race. |
| `incremental-materialized-cache-ktd-logical-work-counters` | Counters wrap real mapper/reducer work. | E2, E8 | aligned |
| `incremental-materialized-cache-ktd-unit-plus-e2e-verification` | Pure logic plus local-backend E2E, not removed Rust fixtures. | E8, E9 | aligned |
| `incremental-materialized-cache-ktd-admin-endpoints` | Knob-gated local status, compare, and debug controls. | E8 | aligned — backend policy |

The matrix has 40 rows: 22 requirements, 8 acceptance examples, and 10
technical decisions. There are no evidence-free rows; policy-labelled rows
are backend-enforceable choices rather than claims of existing behavior.

## Terminology and vehicle check

| Term | Audit result |
|---|---|
| `Current` / `comparison-ready` | Consistent. Serving is a runtime property; comparison-ready adds source-applied, result-published, oracle-observed, and freshness-recorded gates (E10). |
| Required version | Consistent as the connection causal sync watermark; its host read enforcement remains an `incremental-materialized-cache-ktd-view-backed-version-pinned-reads` prerequisite (E8). |
| Applied, published, fence timestamps | Consistent: applied is host progress, published is the read-visible version, fence is the catch-up target before Serving. Their exact storage/API types remain implementation work. |
| Generation invalidation | Consistent as a backend lifecycle rule, but the proposed host support is uncommitted WIP (E8). |
| Fallback reasons | Consistent as lifecycle reasons; `view-version-expired` must remain marked provisional until `incremental-materialized-cache-ktd-view-backed-version-pinned-reads` lands. |
| Proof vehicle | The only binding vehicle is `rooms`, `users`, `memberships`, `messages`, and `likes`, with nullable sender, exact likes, descending `(_creationTime, _id)`, and limit 50 (E9). The older two-table vehicle is historical only. |

## Boundary and test-home checklist

| Boundary | Result | Closing test home |
|---|---|---|
| Atomic multi-table apply | One combined update is supported, but notification ordering is not proven. | `incremental-materialized-cache-u-skip-host-package`: concurrent apply/read test plus notifier re-entrancy test; assert one post-merge notification and no partial graph. |
| Seed/tail fencing | Supported by monotonic log and bounded repeatable snapshots; retention remains an operational constraint. | `incremental-materialized-cache-u-feed-seed-lifecycle` and `incremental-materialized-cache-u-proof-vehicle-corpus-harness`: writes immediately before and after snapshot/fence; retention-loss re-seed. |
| Pinned read and subscription | Not closed. Current `getAll`/`getArray` create then finally close instances, while `subscribe` needs an already-instantiated id; no atomic read-and-arm primitive exists (E1, E8). | `incremental-materialized-cache-u-skip-host-package` then `incremental-materialized-cache-u-version-gate-subscription-compare`: subscribe before first snapshot; test every interleaving and readable-window expiry. |
| Index/schema eligibility | Supported as a host validation policy, not existing cache behavior. | `incremental-materialized-cache-u-registration-host-supervision` and `incremental-materialized-cache-u-proof-vehicle-corpus-harness`: staged/removed/reordered index and wrong `v.id` target before serving. |
| Attributable fallback | Supported by the native Transition path and vocabulary; reasons must be wired. | `incremental-materialized-cache-u-version-gate-subscription-compare` and `incremental-materialized-cache-u-local-backend-wiring`: rebuilding, deadline, host exit, mismatch, ineligible, and unreadable-version cases. |

Every acceptance example has a named test home. The atomic multi-table and
version-gated examples are explicit gap tests, not already-proven behavior;
the remaining examples have executable homes in the corresponding spike units
and corpus/harness.

## Findings

### Required clarification — host surface wording

- **Impacted:** `incremental-materialized-cache-ktd-node-child-host`.
- **Evidence:** `skip:docs/research/research-dir2-host-requirements.md:110` and
  `skip:docs/research/research-dir2-skip-evidence.md:31-64` document a C ABI while calling Node
  the supported, demonstrated interface.
- **Constraint:** Preserve the Node-child decision, but describe direct Rust
  integration as unsupported and out of scope rather than nonexistent.
- **Follow-up:** Amend the spike plan's KTD wording before it is reused as a
  design record. This read-only audit makes no source-plan edit; Node host
  startup smoke remains independent host-package evidence, and no Rust-FFI
  proof is required by this spike.

### Required clarification — pinned read/subscription is a prerequisite

- **Impacted:** `incremental-materialized-cache-ktd-view-backed-version-pinned-reads`,
  `incremental-materialized-cache-version-gated-read`,
  `incremental-materialized-cache-u-skip-host-package`, and
  `incremental-materialized-cache-u-version-gate-subscription-compare`.
- **Evidence:** `skip:docs/research/research-dir2-skip-evidence.md:164-208` labels `read_many`,
  `view-version-expired`, and generation invalidation as uncommitted WIP and
  identifies the snapshot-to-subscribe race. `skip:core/src/index.ts:633-751`
  confirms the separate current primitives.
- **Constraint:** Before the host-package unit starts, write the ordering
  invariant and enforcing mechanism: no apply or notification may be lost
  between the returned snapshot and the armed subscription. Do not depend on
  the WIP as a shipped Skip API. If the host cannot enforce that invariant with
  the current primitives, descope version-gated reads or block on an upstream
  atomic primitive.
- **Closing test:** deterministic interleavings before create, between create
  and subscribe, between subscribe and first snapshot, and after snapshot;
  plus an unreadable captured version that falls back as a whole Transition.

### Required clarification — value boundary must precede oracle equality

- **Impacted:** `incremental-materialized-cache-independent-correctness-check`,
  `incremental-materialized-cache-dangling-typed-reference`, and
  `incremental-materialized-cache-u-proof-vehicle-corpus-harness`.
- **Evidence:** `skip:adapters/convex/src/index.ts:108-131` rejects `v.int64` and
  `v.bytes`; `skip:docs/research/research-dir2-skip-evidence.md:111-129` also calls out missing
  fields versus `null`.
- **Constraint:** Specify either lossless mappings (including missing-field
  treatment) or the explicit safe subset used by the vehicle before comparing
  native and accelerated output.
- **Closing test:** round-trip each admitted value and reject/explain every
  excluded value; separately assert nullable sender is `null`, not absent.

### Required clarification — resource lifetime bounds the scaling conclusion

- **Impacted:** `incremental-materialized-cache-u-skip-host-package` and
  `incremental-materialized-cache-u-scaling-study-verdict`.
- **Evidence:** `skip:docs/research/research-dir2-skip-evidence.md:185-208` notes that one
  per-room resource on first read has no current live-resource bound.
- **Constraint:** Add generation-scoped cleanup, a maximum live-resource
  policy, and resource-count/RSS assertions; otherwise a many-room run may
  measure leaked resources rather than maintained graph state.
- **Closing test:** create more rooms than the bound, reset generation, and
  assert close/eviction plus bounded resource count and RSS reporting.

## Resolved assumptions and smallest implementation-unblocker set

- **Source-verified:** single-collection fork/merge update, inverse reducer
  precedent, monotonic/retained write log, bounded repeatable snapshots, the
  V1-V6 five-table contract, Node as a supported host surface, and registry
  availability for `@skipruntime/core@0.0.23`.
- **Backend-owned policy:** lifecycle states, eligibility handling, fallback
  accounting, no persistence, pre-registration, and admin endpoint gating.
- **External/upstream prerequisite:** the pinned-read protocol must be
  implemented and tested by the host rather than assumed from uncommitted Skip
  work; the installed-artifact smoke and tarball hash are host-package
  prerequisites, with `skargo` required only if registry artifacts fail.

The `incremental-materialized-cache-ktd-node-child-host` wording correction is
required for the spike plan to remain an accurate design record, but it is not
an implementation blocker: the Node-child decision and its startup smoke test
stand without it.

The smallest known implementation-unblocker set is: a written value-boundary
contract and test; a host-owned, serialized
read/subscription protocol with its interleaving and expiry tests; the
notifier-ordering test as a gate for the host-package unit; and the
resource-bound test as a gate for the scaling-study unit. Once these are
accepted as acceptance gates, units may begin only in the readiness order
above, subject to the version-gate feasibility proof.

## Deferred / Open Questions

### From 2026-09-16 review

- **Published runtime artifact compatibility** — Resolved in the audit plan
  after review: the host-package prerequisite now requires an
  installed-artifact smoke covering initialization, one combined update, read,
  and notification, plus the resolved tarball hash. Registry resolution alone
  remains availability evidence, not compatibility evidence.

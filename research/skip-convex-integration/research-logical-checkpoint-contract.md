---
title: Logical checkpoint contract for Q12
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
---

# Logical checkpoint contract (Q12 promotion)

Promotes a language-neutral logical-checkpoint definition into Q12
(`...1159...:83`: standalone spec of Q1 checkpoint + Q3 normalization + Q5
names, implementation-independent; Direction 2 implements native-Rust against
it — `...1702...:317`). Each plan names the same "when may equality be
claimed" concept differently; this doc fixes one shared definition with
per-direction bindings.

## The four gates (all required before equality is claimed)

Gates 1–2 are runtime states (see `research-publication-state-semantics.md`
`Current`); gates 3–4 are harness-side. Serving never waits on the oracle.

1. **Source batch applied** — the direction's indivisible source unit is
   fully ingested (see `research-atomic-source-batch.md`).
2. **Derived result published** — the Skip view/projection for that unit is
   published under the publication-state rules (see
   `research-publication-state-semantics.md`); never partial-as-current.
3. **Native oracle observed** (harness only) — the independent native result
   for the same logical version is available (Shared proof-vehicle contract
   oracle, Q3 normalization).
4. **Freshness state recorded** (harness side, owned by the recorder/Q5) —
   the checkpoint's freshness disposition (current / stale-with-reason /
   fallback-with-reason) is written by the recorder, never inferred from
   silence and never by Q1's settled detector (Q1 detects settled; Q5
   records).

## Per-direction bindings

| Direction | Checkpoint vocabulary | Source | Notes |
|---|---|---|---|
| 1a | writes settled, before next write begins | `...1509...:64` (`sync-protocol-client-settled-checkpoint-comparator` (1a R6)) | Excludes the failure checkpoint itself; R5 freeze verified via AE2, not equality |
| 1b | writes quiesced **or** tagged by workload revision; both paths same revision | `...1843...:63` (1b R9) | Revision-tagging preferred where quiescence is flaky |
| 1c | cursor-after-all-groups + watermarks; failures never advance watermark | `...1854...:79-82` (R8-R11); timers R18 `...1854...:95` | Logical-vs-wall-clock separation required |
| D2 | view ≥ connection's causal sync watermark (max commit version observed) | `...1702...:100-102` (R9-R11) | Cancel/deadline → counted fallback, not comparison |

Q1's detector (`...1159...:72`: `Transition.endVersion.ts` /
`UpToDate(ts)` / required-version marker, one "is settled" predicate) is the
runnable form of gates 1–2; Q3 supplies gate-3 normalization
(`research-spike-comparison.md:85-95`); the Q5 recorder owns gate-4
recording.

## What Q12 must gain

- The four gates above in language-neutral phrasing (data shapes and
  invariants, not TypeScript types or SSE framing).
- The per-direction binding table (this doc's table, pinned to plan lines).
- Failure/exclusion rules: failure checkpoints never count as settled (1a);
  `SplitRequired`/partial windows never current (1b R5/R10); post-header
  failures freeze the watermark (1c R11); abandoned (cancelled/past-deadline)
  reads are non-comparisons, not mismatches (D2 R11).
- N/K/F axis definitions and counter/timer names from Q5
  (`research-spike-comparison.md:17-27,34-49`).

What stays plan-local: transport mechanics, revision-tagging schemes,
watermark storage, deadline values.

## Open questions

- Quiesced vs revision-tagged equivalence: normative equal, or prefer tagging?
- Abandoned-checkpoint state in Q12, or non-comparison by convention?
- Q12 versioning vs 1c KTD10/Q11 JSONL evolution: spec-first or code-first?

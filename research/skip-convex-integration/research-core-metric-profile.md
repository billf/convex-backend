---
title: Core metric profile with direction extensions
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
  - 2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md
---

# Core metric profile (required / optional / N-A + extensions)

Defines common counters/timers as required, optional, or not applicable per
direction — 1a correctly "correctness-only" — then adds page-, cursor-, and
index-gating fields as extensions. 1c's recorder (KTD10/U6) is the most
complete concrete starting point; Q5/Q11 generalize it.

## Core profile table

| Metric | 1a | 1b | 1c | D2 | Basis |
|---|---|---|---|---|---|
| Source rows/bytes | N-A | Required / R12 | Required / R17 | Required via-spec / Q12 | `...1843...:69`; `...1854...:94`; `...1702...:296` |
| Atomic batches | N-A (mechanism only) | Required / R4 | Required / R8 | Required / R2 | P3 single-fork-per-unit (`...1159...:63`) |
| Changed keys | N-A | Required / R12 | Required / R17 | Required via-spec / Q12 | same as above |
| Dependent work | N-A | Required / R12 | Required / R17 | Required / R4 | `...1702...:80` per-stage work |
| Reducer work | N-A | Required / R12 | Required / R17 | Required / R4 | add/remove correctness |
| Stale duration | N-A | Optional | Required / R17-R18 | Timers via R9-R10 | `...1854...:94-95`; `...1702...:96-97` |
| Mismatch | Required / R6 | Required / R9 | Required / R15 | Required / R12-R13 | equality bars; `...1702...:97,101` |
| Fallback | N-A | N-A | N-A (reconnect+stale instead) | Required / R11-R12 | `...1702...:96-97`; see publication-state mapping |

1a exemption: settled-checkpoint equality only, no latency/resource comparison
(`...1509...:64-65`); populates only Q1-Q3 (`...1159...:76`;
`research-spike-comparison.md:65-67`).

## Recorder inventory

- 1c KTD10 (`...1854...:344`: `DataSyncPage`/`SyncResult` stats, per-page
  diagnostics, stage durations, labeled backend metrics, 1b-compatible names)
  + U6 `bench/compare.ts` (`...1854...:632,640`) + U1 scan/emission
  diagnostics (`...1854...:482`).
- 1b R12 (`...1843...:69`) + R11 actual-sizes rule (`...1843...:68`) + R14
  fail gate (`...1843...:71`).
- D2 R4 (`...1702...:80`) + R12 (`...1702...:97`) + R15 (`...1702...:103`,
  no fixed thresholds).
- Q5 superset catalog (`...1159...:76`; `research-spike-comparison.md:34-49`);
  Q11 = 1c JSONL schema (`...1159...:82`); Q12 language-neutral spec
  (`...1159...:83`; see `research-logical-checkpoint-contract.md`).

## Extensions

- Page-specific (1b only): actual page sizes, affected-page counts, splits,
  `id`-change rebuilds, live query-set Add/Remove (`...1843...:68-69`).
- Cursor-specific (1c only): cursor resets, replayed/ignored revisions,
  truncations, reconnects, snapshot-vs-CDC pages, doc-log rows examined,
  wake-ups by cause + suppressed-progress/empty rechecks (`...1854...:94`;
  U2 `...1854...:503-508`; U3 `...1854...:540`).
- Index-gating (D2 only): implicit base views + enabled-index validation
  (R17/R19 `...1702...:108-109`), `v.id` edges (R20-R22 `...1702...:114-116`),
  rebuild state + progress-vs-required-version (`...1702...:97`).

## Name-collision map (canonical Q5 name → direction-tagged alias)

Names may be shared, but 1b delivered snapshot rows and 1c emitted revisions
are **not equivalent efficiency units** (snapshot rows re-deliver unchanged
data per page; revisions count changed documents per transaction). Preserve
both direction-tagged representations side by side and never compute direct
record-count ratios across them — compare each direction against its own
baseline (1b monolithic query, 1c monolithic snapshot), not against each
other's counts.

- Delivered rows/bytes: 1b "rows+bytes delivered" (R12) vs 1c
  "revisions+bytes emitted" (R17) — same canonical slot, tagged units.
- Keys reconciled (added/changed/removed): 1b "Skip keys reconciled" ≡ 1c
  "keys added/changed/removed".
- Rebuilds: 1b "splits+rebuilds (`id` changes)" vs 1c
  "truncations+reconnects+cursor resets+resnapshots" vs D2 "rebuild state".
- Publication: 1b "end-to-end publication" vs 1c "publications + stale
  intervals" vs D2 "view progress vs required version".
- Atomic unit: 1a Transition (R2) ≡ 1c timestamp group (R8) ≡ 1b page-group
  swap (R4) ≡ D2 commit version (R2); see `research-atomic-source-batch.md`.

N/K/F axes + baselines: `research-spike-comparison.md:17-27`
(1c N/K/F `...1854...:467`; 1b loaded-rows analogue; D2 unrelated rooms).

## Open questions

- D2 counter names: Q12 verbatim for R4/R15, or native "stage work" wording
  with a mapping table?
- Canonicalize delivered-count on `revisions` vs `rows` to end the 1b/1c
  collision?
- Is `atomic batches` core or direction-specific, given P3 covers all three
  shapes (`...1159...:63`)?

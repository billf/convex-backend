---
title: Publication-state semantics mapping
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
---

# Publication-state semantics (shared vocabulary, local implementations)

Standardizes a small shared state vocabulary **without** standardizing
implementations. Invariant: **never publish a partial result as current**
(1a `...1509...:120-121`; 1b `...1843...:188-189`; 1c `...1854...:217-218`;
D2 `...1702...:232`). Each direction keeps its lifecycle mechanics; fault
results become comparable through the mapping.

**Runtime vs harness split:** `Current` below is a source/view state — it
must hold during normal serving with no benchmark machinery present. The
oracle-dependent condition is harness-only: **comparison-ready** requires
Current **plus** all four checkpoint gates including the independent native
oracle (see `research-logical-checkpoint-contract.md`). Serving never depends
on the comparator; the comparator never redefines serving states.

## Mapping table

| Shared state | 1a | 1b | 1c | D2 | Distinguisher |
|---|---|---|---|---|---|
| Empty / never-loaded | not-yet-loaded (`...1509...:61`) | no complete window yet (implicit) | Snapshotting, no candidate (`...1854...:377-380`) | rebuilding, native-only (`...1702...:172-174`) | no prior good to freeze |
| Stale / frozen | frozen last-good + indicator (`...1509...:61`) | last-complete window stale (`...1843...:64`) | Stale / Replacing-keeps-last-good (`...1854...:381-390`) | healthy-but-behind waits; unhealthy → fallback (`...1702...:96`) | prior good exists, known-behind |
| Current (runtime) | settled source, view published, freshness known (`...1509...:64` minus oracle) | settled window published, revision known (`...1843...:63` minus oracle) | final group applied + cursor recorded (`...1854...:382` minus oracle) | view ≥ required version, disposition known (`...1702...:95` minus oracle) | source/view gates pass; no oracle needed |
| Comparison-ready (harness only) | Current + oracle match at checkpoint | Current + same-revision oracle match | Current + oracle match, watermark held | Current + oracle match at version | all four checkpoint gates pass (see `research-logical-checkpoint-contract.md`) |
| Removed / gone | `QueryRemoved` deletes in enclosing update (`...1509...:51`) | page removed via swap, no ghost | truncated namespace cleared on promote (`...1854...:78`) | n/a (view-scoped, not row-delete) | intent is unsubscribe/truncate, not failure |
| Terminal / error | FatalError distinct from frozen-stale (`...1509...:184-185`) | none (page failure → stale, never terminal) | versioned `error` event, watermark frozen (`...1854...:82`) | counted native fallback + reason (`...1702...:96-97`) | 1b has no terminal-error; D2 error is substitution, not stream-close |

Lifecycle sources: 1b R4/R5/R10 (`...1843...:53-54,64`, AE5 `:184`);
1c R6/R7 + state diagram (`...1854...:77-78,377-391`); 1c typed errors
(`research-push-stream-seam.md:83-90`); D2 F1-F3
(`...1702...:169-186`); cross-cutting restart/rebuild
(`research-skip-source-state.md:74-84`).

## No-equivalent states (by design)

- 1b `SplitRequired`-incomplete: forces stale-window, has no 1a/D2 counterpart.
- D2 wait-vs-fallback deadline: 1c reconnects + goes stale instead; never
  substitutes a native query.
- 1c Replacing generation: 1a removal is single-Transition, not a multi-page
  candidate.
- FatalError / terminal-`error`: 1a → distinct failure UI; 1c → close,
  cursor frozen, cold-or-resume per retryable flag; D2 → counted fallback;
  1b → stale-window (assert no blank/partial-current per `...1843...:188-189`).

## Fault → state matrix (input to Q6)

Shared fault list: Q6 (`...1159...:78`) + `research-skip-source-state.md:103-113`
(soft limits 16384 entries / 64MiB / 32768 rows; 1b-only splits +
invalid-cursor reset). Each fault forces, per direction: disconnect-before-
checkpoint, cursor expiry/invalid/ahead, table replacement (+ return to
snapshotting), oversized transaction, multi-table atomic transaction,
`QueryFailed` vs `QueryRemoved` vs not-yet-loaded, slow-consumer/backlog
exhaustion, restart mid-CDC. Assertions distinguish freeze-vs-blank-vs-
not-yet-loaded (`research-spike-comparison.md:85-95`).

## Open questions

- Slow-consumer/backlog-exhaustion: Stale (1b/1c) or D2-style fallback — or a
  new shared `Shed` state?
- Does 1b need explicit not-yet-loaded distinct from stale-window for Q6/Q7
  assertions (`...1159...:78-79`)?
- D2 "waiting healthy-behind": observable Stale to the client, or invisible
  until served (affects counter parity with 1c stale-intervals `...1854...:94`)?

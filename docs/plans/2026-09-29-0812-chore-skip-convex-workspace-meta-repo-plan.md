---
title: Convex-Skip Coordination Repo - Plan
type: chore
date: 2026-09-29
topic: convex-skip-coordination-repo
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# Convex-Skip Coordination Repo - Plan

## Goal Capsule

- **Objective:** One personal checkout reproduces the whole Skip/Convex program — plans, research, and the exact tri-repo code state — so any session reviews all plans in one context window, coalesces the work, and tracks it from a single commit instead of reconstructed prose.
- **Means:** New `convex-skip` coordination repo with the three working repos as pinned submodules, plus consolidated docs and workspace-relative paths (KTD1–KTD4). The subrepos hold the actual code changes; `convex-skip` holds coordination and can disappear once that work lands.
- **Authority:** Session-settled scope (submodules; Skip/Convex-only; solo; pin-always) outranks inference; research evidence outranks both for mechanics.
- **Stop conditions:** Stop if a submodule remote refuses the pin (auth), if the scripted path rewrite changes JSON semantics, or if fresh-clone verification fails twice — report, don't force.
- **Execution profile:** Solo operator; four repos touched (one created, three read plus doc-removal commits); submodule work branches are pushed with explicit approval before pinning; no PRs or upstream changes without explicit approval.

---

## Product Contract

### Summary

Build the `convex-skip` coordination repo: consolidated program docs and dev scripts, three pinned submodules, relative paths throughout, and a verification pass proving a fresh clone reproduces today's working state. The subrepos keep the reviewable, upstreamable code; `convex-skip` coordinates and stays disposable.

### Problem Frame

Program knowledge lives in `convex-backend` (get-convex-owned) while the work spans two personal forks, cross-repo references are absolute paths, and tri-repo state is narrated in handoff prose instead of recorded in git. Every session pays reconstruction tax; the next one shouldn't.

### Requirements

**Meta-repo and submodules**

- R1. New personal repo `convex-skip` with `convex-backend`, `skip`, and `convex-tutorial` attached as submodules pinned to recorded SHAs, recursive init covering nested submodules. No pin may point at unpushed content: every pinned SHA is pushed to its remote (with explicit approval) before the milestone superproject commit records it.
- R2. Submodule fetch URLs stay HTTPS, matching the existing remotes exactly; where a repo has two remotes (origin plus upstream), the primary URL is the submodule URL and the second remote is registered explicitly after `submodule add`. Fork pushes may use the SSH remote where HTTPS hits token-scope refusal, so every pinned SHA stays fetchable via HTTPS.

**Doc migration**

- R3. Program docs consolidate per source, counted at execution (never hardcoded): `convex-backend` docs/plans (17 files incl. parent plan and STE companions), `research/skip-convex-integration`, `scripts/skip-local-dev` (12 files), and the one Skip-related solutions entry; `skip` docs tree (plans, research, solutions, backlog — count derived at execution); `convex-tutorial` contributes code only, no docs move. The two generic tooling-decision entries stay.
- R4. Removals land as commits in the source repos; tombstone READMEs remain at old locations; external linkers (`Justfile` recipes, the 1a handoff doc, five review JSONs) are repaired or moved with the plans. Duplicate plans across repos are canonicalized: one survivor per duplicate, the other tombstoned, mapping recorded.

**Portability**

- R5. Zero absolute (`/Users/bill/src`, `$HOME/src`) or tilde (`~/src`) paths remain in moved content, except the three `SKIP_DEV_*_DIR` default assignments in `scripts/skip-local-dev/lib.sh` and their mirror in its README; line-anchored code references stay valid against the pinned SHAs.

**Entry points and conventions**

- R6. Thin root Justfile with explicit-directory recipes (single `Justfile` name) plus `AGENTS.md` recording submodule, worktree, and environment conventions. Script defaults point at the meta-repo submodule paths, never at sibling `.worktrees` checkouts.
- R7. Nothing in the subrepos references `convex-skip`: the dependency runs one way (coordination repo points at code repos), so deleting the coordination repo later is safe.

### Key Decisions

- Program scope is Skip/Convex only, parent prerequisites plan included — user-directed, chosen over a general workspace or leaving the parent code-adjacent. Governs R3, R4.
- Solo use with no other consumers — user-directed, chosen over shared/CI reproducibility. Governs R1, R6.

### Success Criteria

- A fresh `clone --recurse-submodules` yields the three recorded SHAs and passing smoke scripts; the smoke runs with no exported directory overrides.
- Grep gates report zero non-portable paths in moved content.
- All plans are reviewable in one context window under a single root index.

### Scope Boundaries

- Pushing submodule work branches (with explicit approval, so pins resolve) is in scope; PRs, upstream changes, and CI are not; upstream-owned docs untouched.
- Deferred to follow-up work: generalizing the pattern to other programs; CI for the meta-repo.

---

## Planning Contract

### Key Technical Decisions

- KTD1. Pin submodule SHAs at every milestone commit (session-settled: user-approved — chosen over floating branches: atomic state capture outweighs pointer-bump friction). Governs R1.
- KTD2. Fresh submodule checkouts under the meta-repo (session-settled: user-approved — chosen over adopting existing checkouts in place: clean cutover beats state surgery). Governs R1.
- KTD3. New repo is private under the personal account (solo use, no sharing need; flipping visibility later changes nothing structural). Governs R1.
- KTD4. Evidence JSON and machine-generated files get a scripted path rewrite with two gates: identical key sets before/after, plus a value-level gate (allowlisted path-valued fields only, JSON deep-equal otherwise, and a resolve check that each rewritten path exists at the pinned SHA). Prose plans get careful review, never scripted rewrite. Governs R5.
- KTD5. Submodule dirt is inspected at execution before pinning: untracked reference transcripts (e.g. `testdata/sse/`) in the skip worktree get committed in the submodule (with explicit push approval, so the pin resolves) or ignored; tutorial tracked drift (package files) is committed/stashed or explicitly discarded by the same rule. No pin points at unpushed or dirty content. Governs R1.
- KTD6. Line-anchored references are valid only against pinned SHAs; `AGENTS.md` states this so future bumps re-validate or re-anchor them. Governs R5, R6.
- KTD7. The five review JSONs move with the plans, original paths preserved in the move commit message. Governs R4.
- KTD8. Doc histories are imported with `git filter-repo --path` (default; josh only if the experiment is wanted for its own sake): extract the docs subtrees, preserving history, accepting rewritten SHAs. Governs R3.
- KTD9. `convex-skip` stays disposable: no subrepo may reference it (one-way dependency), and end-of-life is an archive commit plus tombstones, never a migration. Governs R7.
- KTD10. `convex-tutorial` is code-only in this migration: no docs move from it; its `.agent-reviews/` stay with the code. Governs R3.
- KTD11. Census counts are derived at execution per source (never hardcoded): backend plans/research/scripts/solutions entry, skip docs tree, tutorial code-only. Gates compare against the derived table. Governs R3.

### High-Level Technical Design

```mermaid
flowchart TB
  A[Create convex-skip] --> B[Attach 3 pinned submodules<br/>recursive init + second remotes]
  B --> C[Move docs + canonicalize duplicates<br/>+ filter-repo histories + tombstones]
  C --> D[Rewrite paths<br/>scripted for JSON (key + value gates), reviewed for prose]
  D --> E[Move scripts + thin Justfile + AGENTS.md<br/>submodule-rooted defaults + root index]
  E --> F[Fresh-clone verification + cutover<br/>no-override smoke]
  F --> G[Milestone superproject commit<br/>all pins pushed]
```

### Assumptions

- Meta-repo lives at `~/src/convex-skip`, origin personal account, private; `gh` authenticated.
- Recorded SHAs are re-resolved at execution (state drifts); current pins are starting points, not authority.

---

## Implementation Units

### U1. Create meta-repo and attach pinned submodules

- **Goal:** Empty personal repo with three working submodules at re-resolved SHAs.
- **Requirements:** R1, R2 (per KTD1, KTD2, KTD5).
- **Dependencies:** None.
- **Files:** New repo root (`.gitmodules`, `.gitignore`, `README.md` pointer).
- **Approach:**
  1. Re-resolve all three submodule SHAs, branches, and dirt at execution start; push each work branch with explicit approval so every pin resolves from a fresh clone.
  2. Create the personal repo and attach each submodule at its re-resolved SHA with matching HTTPS remotes, then register each second remote (skip upstream, tutorial upstream) explicitly.
  3. Recursive init covering nested submodules; confirm clean submodule status.
- **Test scenarios:**
  - Fresh clone with `--recurse-submodules` checks out all three re-resolved SHAs.
  - Second remotes fetch; nested submodules present; no stray files at root.
- **Verification:** SHA equality across all three submodules against the recorded pins.

### U2. Move docs with tombstones and linker repair

- **Goal:** Program docs live in `convex-skip`; old locations point forward.
- **Requirements:** R3, R4 (per KTD7, KTD8, KTD10).
- **Dependencies:** U1.
- **Files:** Moved trees in the coordination repo; tombstone READMEs and repaired linkers in source repos.
- **Approach:**
  1. Confirm `git filter-repo --version` runs (install it first if missing); then import docs-subtree histories with `git filter-repo --path` (KTD8); pair each removal commit in the source repo with the addition in `convex-skip` (backend plans, research tree, scripts, one solutions entry; skip docs tree; tutorial code-only, nothing moved).
  2. Canonicalize duplicates across repos: one survivor per duplicate plan, the other tombstoned, mapping recorded.
  3. Leave tombstones at old dirs; repair handoff links; move the five review JSONs.
  4. Sweep `U`-style cross-references across all moved plans for collisions between repo numbering schemes.
- **Test scenarios:**
  - Per-source file counts match the execution-derived census table (backend/research/scripts/solutions; skip docs; tutorial none).
  - Every external linker resolves again; no program content remains in old locations; no duplicate plan lacks a survivor mapping.
- **Verification:** Census table reconciles; link check passes.

### U3. Rewrite paths to workspace-relative

- **Goal:** No machine-specific paths in moved content.
- **Requirements:** R5 (per KTD4, KTD6).
- **Dependencies:** U2.
- **Files:** Moved docs and research files.
- **Approach:**
  1. Scripted rewrite for evidence JSON with key-set plus value-level gates (including the `$HOME/src` trap in scope review).
  2. Line-by-line review for prose plans; preserve line-anchored refs against pins.
- **Test scenarios:**
  - Grep gates return zero for absolute, tilde, and `$HOME/src` forms outside documented env-defaults.
  - JSON key sets identical pre/post, non-path values deep-equal, rewritten paths resolve at pinned SHAs; spot-check line anchors resolve at pinned SHAs.
- **Verification:** All three gates green.

### U4. Move scripts, thin Justfile, conventions

- **Goal:** Runnable entry points rooted at the coordination repo.
- **Requirements:** R6.
- **Dependencies:** U1, U2, U3.
- **Files:** `scripts/skip-local-dev` (moved by U2; rewired here), root `Justfile`, `AGENTS.md`, `.gitignore` entries, root plan index.
- **Approach:**
  1. Rewire the scripts U2 moved, with no second relocation (the 12-file move and its census stay U2's, counted under R3); re-root directory derivations to the coordination repo with env overrides: the backend-root derivation depth is unchanged (scripts stay two levels below root, now resolving to the coordination root), and the tutorial/skip defaults become `<root>/convex-tutorial` and `<root>/skip`.
  2. Single `Justfile` name with explicit-directory recipes; record submodule, worktree, and environment conventions; extend the identifier-map pattern to a `convex-skip` root index so all plans read in one context.
- **Execution note:** Packaging and config work; prefer smoke verification over unit coverage.
- **Test scenarios:**
  - Each wrapper recipe resolves its target directories from a fresh shell.
  - Overrides redirect all three roots; the no-override smoke uses submodule defaults only; conventions doc names the pin-bump and worktree-merge rules.
- **Verification:** Wrapper dry-runs resolve correctly; doc states the conventions.

### U5. Fresh-clone verification and cutover

- **Goal:** Proven reproducibility, then removal of old locations.
- **Requirements:** All R1–R7.
- **Dependencies:** U2, U3, U4.
- **Files:** Milestone superproject commit; deleted old paths in source repos.
- **Approach:**
  1. Temp fresh clone; SHA, gate, and smoke verification (sandbox-aware: `lsof`-based checks, user terminal for network steps per the recorded learning).
  2. Delete old locations exactly as listed and record the milestone commit.
- **Execution note:** Smoke-first; network-touching steps may need the user's terminal under sandbox restrictions.
- **Test scenarios:**
  - Clone reproduces SHAs; moved smoke scripts pass; old paths gone; superproject log shows the milestone.
- **Verification:** Definition of Done holds end to end.

---

## Verification Contract

| Scope | Command | Proves |
|---|---|---|
| Pins | SHA equality across submodules vs recorded pins | U1, R1 |
| Census | file counts reconcile with research inventory | U2 |
| Portability | grep gates for absolute/tilde/`$HOME/src` forms | U3, R5 |
| Entry points | wrapper resolution + smoke scripts | U4, U5 |
| Reproducibility | temp fresh clone green | U5, DoD |

---

## Definition of Done

- One checkout reproduces docs, scripts, and exact tri-repo state from a single commit.
- Moved content is portable; old locations tombstoned then removed after green.
- No code changed in any repo; work-branch pushes only with explicit approval; no PRs made.
- Abandoned-attempt artifacts removed from the diff.

---

## Risks & Dependencies

- Nested submodules in `skip` require recursive handling; transcript dirt was committed under KTD5 at U1 execution.
- Pushing a branch whose history contains workflow-file updates can hit OAuth token-scope refusal; the SSH remote works — prefer it for fork pushes.
- Sandbox network restrictions may push smoke verification to the user's terminal.
- Research found no submodule-specific prior learnings; pointer discipline rests on the new conventions doc.

---

## System-Wide Impact

Solo operator only. The cross-repo touches are tombstones plus removal commits in the source repos; upstream history is otherwise untouched.

---

## Sources / Research

- Explore-pass inventory (per-source move set, path census, linker list, nested submodules, `lib.sh` trap).
- Executed U1 pins: backend `258bdfb` (`billf/1c`, pushed to the personal fork via SSH after token-scope refusal), skip `08e7475` (`feat/skip-shared-prereqs`, incl. committed transcripts), tutorial `59d7abe` (`feat/skip-shared-prereqs`); fresh-clone check green.
- `docs/solutions/build-errors/agent-sandbox-blocks-loopback-network.md` (sandbox verification constraints).
- Session scope confirmation (submodules, program scope, solo, pin-always).

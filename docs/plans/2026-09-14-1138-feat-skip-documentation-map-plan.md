---
title: Skip Cross-Plan Documentation Map - Plan
type: feat
date: 2026-09-14
topic: skip-cross-plan-documentation-map
artifact_contract: ce-unified-plan/v1
product_contract_source: review-map
execution: code
---

# Skip Cross-Plan Documentation Map - Plan

> **Superseded in part (2026-09-23).** This completed plan records the maps as built on 2026-09-14. Since then 1a, 1b, and 1c all adopt P/Q as direct dependencies (1a/1b the snapshot baseline; 1c also the revision-delta extensions), and 1c's bespoke fallback was withdrawn. Statements below about a 1a/1b sequencing claim, 1c's optional reuse, and its fallback are historical; the current relationships are in [prerequisites.md](prerequisites.md), [detailed-prerequisites.md](detailed-prerequisites.md), and the [shared prerequisites plan](2026-09-11-1159-feat-skip-shared-prerequisites-plan.md).

## Goal Capsule

- **Objective:** Help readers understand the two Skip/Convex directions, each plan's maturity and dependencies, and how to maintain cross-document references. A proposed sequencing dependency must not be mistaken for a technical impossibility.
- **Means:** Establish three canonical diagram documents, make the directory README the maintenance contract, reconcile stable cross-plan anchors, and give each dated plan self-contained local diagrams. (KTD1, KTD2)
- **Product authority:** The supplied review map is authoritative for scope, status taxonomy, dependency semantics, validation, and review requirements.
- **Stop conditions:** Do not overwrite the existing working-tree version of `docs/plans/IDENTIFIER-MAP.md`; do not send document content to OpenCode until the user authorizes that egress.

---

## Product Contract

### Summary

Document the distinct strategic boundaries of Direction 1 (Skip as an external incremental consumer) and Direction 2 (a backend-owned materialized-view engine). Add canonical cross-plan Mermaid maps and plan-local diagrams so the directory remains readable and maintainable as its plans change.

### Problem Frame

The current README overstates P/Q as a hard prerequisite for every Direction 1 implementation and does not provide a canonical, stable graphical map of maturity, dependencies, and identifiers. The sibling plans have different ownership and validation boundaries: P/Q sequence 1a and 1b under the shared plan, 1c can start independently, and Direction 2 consumes Q12 as a specification rather than P/Q code.

### Key Decisions

- **Describe P/Q as a recorded sequencing claim, not a proven impossibility.** 1a/1b may be scheduled behind P/Q; 1c retains its documented fallback and Direction 2 owns its native work. Governs R1, R3, R4. *(Historical; superseded 2026-09-23: direct P/Q dependency, fallback withdrawn.)*
- **Use descriptive anchors for all cross-document graph and prose references.** Numbered P/Q/R/U identifiers remain local metadata, not cross-plan link targets. Governs R2, R5.
- **Keep canonical cross-plan graphs separate from dated-plan diagrams.** The three standalone documents own the shared topology; each dated plan owns only its local boundary. Governs R2, R6.

### Requirements

- R1. `docs/plans/README.md` distinguishes Direction 1's external-consumer boundary from Direction 2's backend-owned boundary and accurately states each direction's implementation preconditions.
- R2. `docs/plans/planning-timeline.md`, `docs/plans/prerequisites.md`, and `docs/plans/detailed-prerequisites.md` are canonical, standalone Markdown graph documents with readable Mermaid diagrams and links to the plans and identifier map they summarize.
- R3. The timeline document defines requirements-only, decision-complete, implementation-ready, built, validated, and generalization-decision states; it maps complete inputs, usable, and stable consistently across all plans.
- R4. The prerequisite documents show the shared vehicle/research path, P/Q, 1c's independent implementation island and constrained integration-validation gate, and Direction 2's backend-native path consuming `shared-prereqs-q-language-neutral-methodology-spec` as a specification.
- R5. `docs/plans/IDENTIFIER-MAP.md` correctly maps plan slugs and every used cross-plan descriptive anchor to its source plan before new cross-plan prose or graphs cite it.
- R6. Each of the five dated plans has a labeled dependency-relations Mermaid diagram and a labeled actors-and-flows Mermaid diagram that remain local to that plan and point readers to the canonical cross-plan documents.
- R7. The README is the canonical cross-document graph maintenance contract, while each dated plan carries only a one-line maintenance pointer linking the three graph documents and `IDENTIFIER-MAP.md`.
- R8. Every changed Mermaid block is extracted and rendered successfully; valid cross-model review findings are applied and the final references, rendered artifacts, and working tree are rechecked. Cross-model document egress requires separate user authorization.

### Acceptance Examples

- AE1. A reader comparing 1a, 1b, and 1c sees P/Q as the shared plan's proposed sequencing dependency for 1a/1b, sees 1c as implementation-ready, and sees its integration gate conditioned on usable P/Q or a documented bespoke fallback. *(Historical; superseded 2026-09-23: no fallback, direct P/Q dependency for 1a, 1b, and 1c.)*
- AE2. A reader evaluating Direction 2 sees Q12 as a methodology specification and does not infer that Direction 2 consumes TypeScript P/Q code or inherits Direction 1's atomicity implementation.
- AE3. A maintainer changes a dated plan, follows its one-line pointer, updates the relevant canonical graph node/edge/status and identifier-map row, then reruns Mermaid rendering and reference resolution.

### Scope Boundaries

**Deferred to Follow-Up Work**

- Build any of the described 1a, 1b, 1c, P/Q, or Direction 2 implementation units.
- Resolve the shared-prerequisites plan's remaining Direction 2 code-companion decision.

**Outside this product's identity**

- Alter the technical plans' product contracts, ownership boundaries, or implementation readiness beyond correcting stale cross-document documentation.
- Add an OpenCode review provider, model dependency, or repository dependency solely for this documentation change.

### Dependencies / Risks

- The existing `docs/plans/IDENTIFIER-MAP.md` may carry working-tree edits. Reconcile against its committed baseline plus any working-tree content, preserving unrelated edits.
- Mermaid CLI rendering must use a locally installed `mmdc` or an ephemeral `npx` invocation without adding dependencies.
- The requested OpenCode review is an external disclosure. Work can complete local validation without it, but the cross-model review gate remains pending until the user authorizes egress.

### Sources / Research

- `docs/plans/README.md` — current, stale prerequisite wording and existing direction overview.
- `docs/plans/IDENTIFIER-MAP.md` — stable anchors and current working-tree reconciliation target.
- The five dated plan files — authoritative local requirements, states, and plan-local flows.
- Sibling Skip research under `research/skip-convex-integration/` (`README.md`, `overview.md`, `research-skip-source-state.md`, `research-data-sync-source.md`, `research-spike-comparison.md`) — corroborate the status and ownership boundaries above; resolve the exact file per claim during U1 reconciliation.

---

## Planning Contract

### Key Technical Decisions

- **KTD1. Make status taxonomy explicit before drawing dependencies.** State is represented as a vocabulary and applied consistently, instead of inferred from dates or an older readiness field.
- **KTD2. Let `IDENTIFIER-MAP.md` own stable cross-plan anchors.** Graph labels and prose link to descriptive anchors; source plans retain their own local identifiers.
- **KTD3. Generate only self-contained plan-local diagrams in dated plans.** External references may enter or leave a local diagram at its boundary but sibling internals remain in canonical documents.
- **KTD4. Validate source and render output, then perform an authorized independent review.** Treat renderer errors, missing extraction, invalid review JSON, and unavailability as distinct outcomes rather than evidence of agreement.

### High-Level Technical Design

```text
source plans + Skip research
             │ reconcile anchors and status facts
             ▼
IDENTIFIER-MAP ──► canonical timeline / dependency documents ──► README maintenance contract
                         │                                      │
                         └────────► local diagrams + pointers ◄──┘
                                             │
                                             ▼
                         extract → render SVG → authorized review → rerender and link audit
```

### Implementation Sequence

First reconcile names and facts, then write canonical graphs and README contract, then add each plan's local diagrams and maintenance pointer. Render all affected Mermaid sources before and after any valid review-driven correction.

---

## Implementation Units

### U1. Reconcile cross-plan anchors and source facts

**Goal:** Establish a working-tree-safe identifier map and a fact table for all later documentation.

**Requirements:** R3, R4, R5.

**Dependencies:** None.

**Files:** `docs/plans/IDENTIFIER-MAP.md`; five dated plan files; `docs/plans/README.md`.

**Approach:** Compare every plan's frontmatter topic and cross-plan references with the existing identifier-map rows. Correct stale slug/source-file mappings and add or amend only anchors actually consumed by canonical graph labels or prose. Preserve unrelated local map changes.

**Test scenarios:**

- A referenced descriptive anchor resolves to one source plan and describes the same requirement or decision.
- No new cross-plan graph label uses a bare P/Q/R/U number.
- The committed identifier-map rows plus any working-tree edits remain present after reconciliation.

**Verification:** A scripted or reproducible link audit maps every graph and README anchor reference to `IDENTIFIER-MAP.md` or its owning source plan.

### U2. Create the canonical timeline document

**Goal:** Give readers a consistent maturity and sequencing view.

**Requirements:** R2, R3.

**Dependencies:** U1.

**Files:** `docs/plans/planning-timeline.md`.

**Approach:** Define the state taxonomy in prose, then add composable Mermaid planning, implementation, and complete graphs. Use the reconciled descriptive anchors and explicitly distinguish complete inputs from usable interfaces and stable interfaces.

**Test scenarios:**

- The planning graph places 1a, 1b, P/Q, and Direction 2 in requirements-only with their unresolved decisions, and places 1c in implementation-ready.
- The implementation graph shows 1c's independent start and conditional integration-validation gate.
- The complete graph composes the planning and implementation subgraphs without changing the state labels' meaning.

**Verification:** Each Mermaid block extracts and renders to SVG; the prose and graph labels agree with the sibling plans.

### U3. Create the canonical prerequisite documents

**Goal:** Make dependency and consumption boundaries legible without coupling sibling plan internals.

**Requirements:** R2, R4.

**Dependencies:** U1.

**Files:** `docs/plans/prerequisites.md`; `docs/plans/detailed-prerequisites.md`.

**Approach:** Use a compact high-level graph for the vehicle/research path, P/Q, 1c island, and Direction 2 path. Expand P and Q by named outputs and label each downstream relationship as code consumption, specification consumption, optional reuse, design reference, or planned gate.

**Test scenarios:**

- 1a/1b show planned P/Q sequencing gates rather than a hard technical block. *(Historical; superseded 2026-09-23: direct dependency by decision.)*
- 1c shows P/Q as optional reuse, with its documented fallback satisfying the independent start condition. *(Historical; superseded 2026-09-23: direct dependency, fallback withdrawn.)*
- Direction 2 consumes `shared-prereqs-q-language-neutral-methodology-spec` as a specification and shows native atomicity/comparator work as its own.

**Verification:** Both documents render, use only stable anchors for cross-plan references, and link to their owning plans and the identifier map.

### U4. Rewrite the directory README as the canonical overview and maintenance contract

**Goal:** Make the README the accurate entry point and sole full maintenance rule.

**Requirements:** R1, R7.

**Dependencies:** U1, U2, U3.

**Files:** `docs/plans/README.md`.

**Approach:** Replace stale prerequisite language with the reviewed ownership and state model, link all three canonical graph documents, and add the complete maintenance requirement for graph nodes, edges, statuses, identifier rows, rendering, and resolution checks.

**Test scenarios:**

- Direction 1 and Direction 2 have distinct ownership, deployment, protocol, and comparator boundaries.
- The README does not say P/Q prove 1a/1b cannot proceed independently.
- The maintenance rule points a maintainer to all three graph documents and `IDENTIFIER-MAP.md`.

**Verification:** README links resolve locally and its status claims match the canonical graph documents and dated plan evidence.

### U5. Add dated-plan local diagrams and maintenance pointers

**Goal:** Make each plan understandable in isolation without duplicating the cross-plan topology.

**Requirements:** R6, R7.

**Dependencies:** U1, U2, U3, U4.

**Files:** `docs/plans/2026-09-10-1509-feat-skip-sync-protocol-client-plan.md`; `docs/plans/2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md`; `docs/plans/2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md`; `docs/plans/2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md`; `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`.

**Approach:** Add two explicitly labeled Mermaid diagrams per plan: dependency relations and actors/flows. Keep sibling detail out of the diagrams; use named external references only at an ingress or egress boundary. Add the concise pointer to the canonical maintenance contract.

**Test scenarios:**

- Each dated plan contains exactly one clearly labeled local dependency graph and one clearly labeled local actors-and-flows graph for this change.
- A local graph exposes its prerequisites, deliverables, validation gate, and allowed external boundary without reproducing a sibling plan's internals.
- The maintenance pointer links `planning-timeline.md`, `prerequisites.md`, `detailed-prerequisites.md`, and `IDENTIFIER-MAP.md`.

**Verification:** All ten plan-local Mermaid blocks render and each plan remains internally consistent with its requirements and implementation units.

### U6. Render and audit the documentation set

**Goal:** Prove every changed graph is syntactically valid and every cross-document reference resolves.

**Requirements:** R8.

**Dependencies:** U1-U5.

**Files:** Changed `docs/plans/*.md` graph documents and dated plans.

**Approach:** Extract all target Mermaid fences to a named ephemeral directory, render one SVG per source with local `mmdc` or ephemeral `npx`, inspect failures and SVG readability, then rerender the entire set. Preserve the directory through the review outcome. If neither renderer is available, quarantine the failing blocks, merge prose with explicit unrendered status, and record the unavailability evidence rather than blocking the set on rendering alone.

**Execution note:** Prefer renderer evidence over visual assumptions; inspect generated SVGs rather than accepting a zero exit status alone.

**Test scenarios:**

- Every targeted Mermaid fence creates a nonempty `.mmd` file and corresponding SVG.
- Invalid Mermaid syntax and extraction failure make validation fail distinctly; renderer unavailability follows the quarantine-and-record path instead of failing the set.
- Every cross-document descriptive anchor and Markdown link resolves after the final render.

**Verification:** Report the preserved ephemeral directory, block/source count, SVG count, renderer version, and link-audit outcome.

### U7. Run the authorized cross-model review and close validation

**Goal:** Incorporate independent review without treating reviewer absence as agreement.

**Requirements:** R8.

**Dependencies:** U6.

**Files:** Changed `docs/plans/*.md` artifacts; ephemeral Mermaid source/SVG directory; temporary self-contained review brief.

**Approach:** Only after the user authorizes egress, smoke-test the exact OpenCode model and flags, then serialize schema-directed reviews from an empty temporary directory using the supplied model and a self-contained brief containing final Markdown plus rendered SVG content. Validate the JSON text event, apply valid findings, rerender all diagrams, rerun the link audit, and inspect final diff/status. Record invalid or missing payloads as reviewer unavailability.

**Test scenarios:**

- The reviewer can assess every target artifact from the brief alone, without repository paths.
- A valid schema result is distinguishable from an invalid, missing, timeout, or unavailable result.
- Applying a valid finding triggers a full rerender and reference audit.

**Verification:** Save the review receipt or reviewer-unavailability evidence alongside the final validation summary; do not send a brief before authorization.

---

## Verification Contract

| Area | Evidence | Units | Expected outcome |
|---|---|---|---|
| Anchor audit | Search all changed graph labels, prose citations, and Markdown links against `IDENTIFIER-MAP.md` and source plans | U1-U5 | Every cross-plan reference resolves through a descriptive anchor or direct owning-plan link. |
| Mermaid rendering | Extract target fences to a preserved ephemeral directory and render each with `mmdc` (or ephemeral `npx`) | U2-U6 | Every source produces a readable SVG with no extraction or render error. |
| Documentation coherence | Inspect README, three canonical documents, and each dated plan's two local diagrams | U2-U6 | Status, dependency, ownership, and maintenance claims agree. |
| Cross-model review | Authorized OpenCode schema-directed review from an empty workdir | U7 | Valid findings are applied and revalidated; invalid or missing payload is explicitly recorded as unavailable. |
| Final hygiene | `git diff --check`, targeted diff inspection, and `git status --short` | U1-U7 | No whitespace errors and no pre-existing `IDENTIFIER-MAP.md` work is overwritten. |

---

## Definition of Done

- U1 is done when the working-tree identifier map is reconciled and every new cross-plan reference uses a stable descriptive anchor.
- U2-U3 are done when the three canonical documents define and render the required timeline and prerequisite graphs.
- U4 is done when the README accurately describes both directions, their actual preconditions, and the complete maintenance rule.
- U5 is done when all five plans include only self-contained local diagrams and concise maintenance pointers.
- U6 is done when every target Mermaid block has a successfully rendered SVG in the preserved ephemeral directory and all cross-plan links resolve.
- U7 is done only after explicit egress authorization; if authorization is withheld, local work remains complete but the external-review gate is reported as pending rather than silently waived.
- The final diff contains no abandoned validation artifacts or repository dependency changes, and it preserves the user's pre-existing `docs/plans/IDENTIFIER-MAP.md` edits.

---

## Progress

- [x] Plan committed as baseline (review-driven premises, research paths, and renderer fallback applied).
- [x] U1 — identifier map and descriptive anchors reconciled against the dated plans without overwriting unrelated working-tree content.
- [x] U2 — timeline taxonomy and dependency graphs verified and amended for the Direction 2 Q12 specification boundary.
- [x] U3 — prerequisite maps verified and amended so 1c's optional P/Q reuse attaches only to integration validation. *(Historical; superseded 2026-09-23: direct P/Q dependency, fallback withdrawn.)*
- [x] U4 — README ownership, state, links, and maintenance contract verified.
- [x] U5 — all five dated plans verified with two local diagrams and a canonical-maintenance pointer.
- [x] U6 — all 21 Mermaid blocks rendered successfully to `/private/tmp/skip-doc-graphs-final-review-aXsPgm` with ephemeral `npx @mermaid-js/mermaid-cli` 11.17.0; 57 local Markdown links resolved.
- [x] U7 — authorized OpenCode review returned valid JSON; five confirmed findings were applied, then all diagrams and links were revalidated.

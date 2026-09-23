# Skip/Convex prerequisite map

This graph distinguishes planned gates, direct dependencies, and design-reference
relationships. It does not make a sequencing proposal into a claim that a
spike is technically impossible to implement another way.

```mermaid
flowchart TB
  research["Complete input: shared research"]
  vehicle["Complete input: common PoC vehicle"]
  shared["Shared P/Q plan"]
  p["P baseline\nAtomic-source-batch contract"]
  q["Q harness\nComparator and fault fixture"]
  q12["shared-prereqs-q-language-neutral-methodology-spec"]
  oneA["1a sync-protocol client"]
  oneB["1b paginated reactive source"]
  oneC["1c Data Sync push source"]
  two["Direction 2 materialized cache"]
  oneCValidation["1c integration validation"]
  pRd["P revision-delta extension\n(P4, P5, P9)"]
  q13["Q13 proof-vehicle fixture"]

  research --> shared
  vehicle --> shared
  shared --> p
  shared --> q
  q --> q12
  p --> pRd
  q --> q13
  p -. "planned sequencing gate" .-> oneA
  q -. "planned sequencing gate" .-> oneA
  p -. "planned sequencing gate" .-> oneB
  q -. "planned sequencing gate" .-> oneB
  oneC -->|"U4-U6 verified only with P/Q"| oneCValidation
  pRd -->|"direct dependency (U4)"| oneCValidation
  q13 -->|"direct dependency (U5)"| oneCValidation
  q -->|"direct dependency (U6)"| oneCValidation
  q12 -. "specification consumption" .-> two
  p -. "design reference only" .-> two
  q -. "design reference only" .-> two
```

- **Planned sequencing gate:** the shared plan proposes P/Q before 1a or 1b
  so they can reuse a common convention and comparator. The shared plan's
  recorded challenge to a “hard prerequisite” framing remains controlling.
- **Direct dependency (1c, adopted 2026-09-23):** 1c can start its backend
  units and push-service parser work without P/Q, but its push service (U4)
  imports P's snapshot baseline plus the revision-delta extension, its tutorial
  unit (U5) consumes Q13's fixture, and its comparison harness (U6) builds on
  Q with both Q6 fault tiers. There is no bespoke fallback; P/Q gaps are fixed
  in the shared plan. 1a and 1b wait only on the snapshot baseline, never on
  the revision-delta extensions.
- **Specification consumption:** Direction 2 implements native atomicity and
  comparator code, but uses Q12's language-neutral methodology rather than
  importing TypeScript P/Q artifacts.
- **Encoding boundary:** 1a/1b use complete `SnapshotBatch` values; 1c uses
  `RevisionDeltaBatch`; Direction 2 implements the latter's native equivalent.
  In 1b, incoming Transition groups and page-swap publication groups are
  intentionally distinct.
- **Design reference:** a relationship informs a design but supplies no code
  dependency or completion gate.

Cross-document descriptive anchors above resolve through
[IDENTIFIER-MAP.md](IDENTIFIER-MAP.md); generic P/Q node labels are local to
this diagram. See [planning-timeline.md](planning-timeline.md) for maturity
states and [detailed-prerequisites.md](detailed-prerequisites.md) for the P/Q
outputs.
The source plans are [1a](2026-09-10-1509-feat-skip-sync-protocol-client-plan.md),
[1b](2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md),
[1c](2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md),
[Direction 2](2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md),
and [the shared P/Q prerequisites](2026-09-11-1159-feat-skip-shared-prerequisites-plan.md).

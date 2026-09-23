# Skip/Convex planning timeline

This timeline uses the same maturity terms for every plan in this directory.
It compares two strategic directions without treating them as phases of one
implementation.

## State taxonomy

- **Requirements-only:** product scope is captured, but implementation choices
  still need planning.
- **Decision-complete:** the decisions needed to plan are settled, but the
  implementation plan has not yet been written or reconciled.
- **Implementation-ready:** implementation units and verification criteria are
  defined; work may start.
- **Built:** the planned implementation exists, but its planned integration
  proof has not yet passed.
- **Validated:** the planned correctness and integration proof has passed.
- **Generalization decision:** evidence is sufficient to decide whether to
  harden, expand, or stop a direction; this is a decision state, not an
  automatic production commitment.

**Complete inputs** are research and the common PoC vehicle. **Usable** means
P baseline or Q is implemented and integrated by a real consumer. **Stable**
means that real-consumer integration has shown its interface needs no bespoke
adaptation. A plan can be implementation-ready before the shared P/Q it
depends on becomes usable or stable.

## Planning state

```mermaid
flowchart TB
  research["Complete input: Skip/Convex research"]
  vehicle["Complete input: common PoC vehicle"]
  oneA["1a sync-protocol client\nRequirements-only\nAdopts P snapshot baseline and Q"]
  oneB["1b paginated reactive source\nRequirements-only\nAdopts P snapshot baseline and Q"]
  shared["P/Q shared prerequisites\nRequirements-only\nDecide package and harness topology"]
  oneC["1c Data Sync push source\nImplementation-ready\nCan start without P/Q"]
  two["Direction 2 materialized cache\nImplementation-ready\nNode-child Skip host, write-log tail, native comparator"]

  research --> oneA
  research --> oneB
  research --> shared
  research --> oneC
  research --> two
  vehicle --> shared
  vehicle --> oneC
  vehicle --> two
```

## Implementation and validation state

```mermaid
flowchart LR
  sharedPlan["P/Q planned"] --> pBaseline["P baseline built"]
  sharedPlan --> qHarness["Q harness and language-neutral methodology specification built"]
  qHarness --> q12["shared-prereqs-q-language-neutral-methodology-spec"]
  pBaseline --> usableP["P usable after real-consumer integration"]
  qHarness --> usableQ["Q usable after real-consumer integration"]
  usableP --> stableP["P stable interface"]
  usableQ --> stableQ["Q stable interface"]

  oneA["1a implementation"] --> oneAProof["1a validation"]
  oneB["1b implementation"] --> oneBProof["1b validation"]
  oneC["1c implementation"] --> oneCProof["1c integration validation"]
  two["Direction 2 native implementation"] --> twoProof["Direction 2 validation"]

  pBaseline -->|"direct dependency"| oneAProof
  qHarness -->|"direct dependency, incl. Q13 and Q14"| oneAProof
  pBaseline -->|"direct dependency"| oneBProof
  qHarness -->|"direct dependency, incl. Q13 and Q14"| oneBProof
  usableP -->|"direct dependency, incl. revision-delta extension"| oneCProof
  usableQ -->|"direct dependency, incl. Q13, Q14, applicable Q6 faults"| oneCProof
  q12 -. "shared-prereqs-q-language-neutral-methodology-spec" .-> two
  oneAProof --> decision["Generalization decision"]
  oneBProof --> decision
  oneCProof --> decision
  twoProof --> decision
```

## Complete view

```mermaid
flowchart TB
  subgraph Planning["Planning"]
    plan1a["1a requirements-only"]
    plan1b["1b requirements-only"]
    planPQ["P/Q requirements-only"]
    plan1c["1c implementation-ready"]
    plan2["Direction 2 implementation-ready"]
  end

  subgraph Delivery["Implementation and validation"]
    d1["P/Q built → usable → stable"]
    d2["1a/1b build; validate with P/Q snapshot baseline"]
    d3["1c build; validate with P/Q (no fallback)"]
    d4["Direction 2 native build; validate against shared-prereqs-q-language-neutral-methodology-spec"]
    d5["Generalization decision"]
  end

  planPQ --> d1
  plan1a --> d2
  plan1b --> d2
  plan1c --> d3
  plan2 --> d4
  d1 -->|"direct dependency for 1a/1b"| d2
  d1 -->|"direct dependency for 1c U4-U6"| d3
  d2 --> d5
  d3 --> d5
  d4 --> d5
```

See [prerequisites.md](prerequisites.md) for dependency boundaries and
[detailed-prerequisites.md](detailed-prerequisites.md) for P/Q outputs. The
cross-document descriptive anchors used in these graphs are defined in
[IDENTIFIER-MAP.md](IDENTIFIER-MAP.md); their other node labels are local to
these diagrams.
The source plans are [1a](2026-09-10-1509-feat-skip-sync-protocol-client-plan.md),
[1b](2026-09-10-1843-feat-skip-paginated-reactive-source-spike-plan.md),
[1c](2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md),
[Direction 2](2026-09-10-1702-feat-skip-incremental-materialized-cache-spike-plan.md),
and [the shared P/Q prerequisites](2026-09-11-1159-feat-skip-shared-prerequisites-plan.md).

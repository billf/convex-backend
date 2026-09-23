# Cross-spike traceability matrix

This matrix is the normative cross-reference for the four Skip/Convex spikes.
The shared prerequisites plan owns the product contract, `AtomicSourceBatch`,
Q12 checkpoint contract, semantic corpus, core metric vocabulary (Q11's single
schema authority), the Q13 proof-vehicle fixture, and the Q14 no-torn observer.
Local plans retain their own transport, cursor, deadline, recovery, and lifecycle
mechanics.

| Concern | 1a — sync protocol | 1b — paginated source | 1c — Data Sync push | Direction 2 — materialized cache |
|---|---|---|---|---|
| Product contract | Complete five-table, native-oracle feed | Same 50-row observable feed; pages are acquisition only | Same five-table retained feed | Same pre-registered feed |
| Incoming group | Reassembled `Transition` | Transition transport group | Exact-`ts` group | Committed transaction |
| Publication boundary | One complete Transition snapshot | One page-region swap after both replacements complete | One complete revision group | Native atomic commit-version publish |
| Batch encoding | `SnapshotBatch`, `end_version.ts` | `SnapshotBatch`, page-set version | `RevisionDeltaBatch`, `ts`/`snapshotTs`/cursor | Native `RevisionDeltaBatch` equivalent, commit version/causal watermark |
| Delete and replay | `QueryRemoved` in enclosing full value; fresh reconnect snapshot | Region swap removes old page; `InvalidCursor` full reset | `_id` tombstone + per-document watermark; cursor after all groups | Native delete/rebuild/replay implementation |
| No-torn assertion | Q14 observer sees no partial Transition | Q14 observer sees no half-swapped current region | Q14 observer sees no partial timestamp-group publication | Native Q12-equivalent observer sees no partial transaction-version publish |
| Q12 checkpoint | Transition applied → result published → oracle observed → freshness recorded | Same gates, revision-tagged or quiesced (both via Q1) | Same gates, cursor advances only after groups | Same gates, view ≥ causal required version |
| Runtime state | `current` / stale / not-yet-loaded | `current` / stale / incomplete split | `current` / stale / snapshotting / replacing | current / rebuilding / fallback |
| Harness state | `comparison-ready` only after oracle | Same | Same | Same |
| V1–V6 corpus | All vectors; V4 boundary/tie; V6 final-state equality; live no-torn observation | All vectors; V4 requires 50 qualifiers or native shortfall proof; V6 final-state equality; live no-torn page-swap observation | All vectors; V4 boundary/tie; V6 final-state equality; live no-torn timestamp-group observation | All vectors; V4 boundary/tie; V6 final-state equality; live no-torn transaction observation |
| Required metric posture | Correctness-only: Q1–Q3 plus mismatch | Snapshot rows plus page extensions | Revision rows plus cursor extensions | Native stage work plus fallback/index extensions |
| P/Q consumption | Direct dependency (adopted 2026-09-23): P snapshot baseline (per-query keys); Q with snapshot-path fault baseline incl. query-state faults; Q13 fixture and per-table subscription queries; Q14 | Direct dependency (adopted 2026-09-23): P snapshot baseline (page-region keys); Q with snapshot-path baseline plus 1b-supplied split/invalid-cursor triggers; Q13 fixture, supporting inputs, and bounded monolithic baseline; Q14 | Direct dependency (adopted 2026-09-23): P snapshot baseline plus revision-delta extension (P4, P5, P9); Q13 fixture incl. all-selected-rows baseline; Q with both Q6 tiers except the baseline's query-state faults; Q14; no local fallback | Q12 specification only; native atomicity and comparator; may vendor Q13's schema and corpus manifest |
| Index assumption | Shared static indexes enabled | Same; `by_room` drives pages | Same | Same static set plus lifecycle eligibility tests |

`current` never depends on the comparator. `comparison-ready` is harness-only,
requires the native oracle, and is not a serving prerequisite. Snapshot-row and
revision counts share a reporting slot but are direction-tagged representations,
not directly comparable efficiency units.

## Static index set

Every direction begins with `memberships.by_room_user[room,user]`,
`messages.by_room[room]`, `messages.by_sender[sender]`, and
`likes.by_message[message]` enabled, plus the built-in ID and creation-time
indexes. Only Direction 2 tests staged, disabled, removed, incompatible, and
rebuild/fallback index lifecycle behavior. `messages.by_sender` supports its
nullable-sender rename/deletion reverse join; no `[room,sender]` index is part
of this spike.

## Corpus and evidence

The materialized [`semantic-vectors-v1.md`](../../research/skip-convex-integration/semantic-vectors-v1.md)
manifest records the fixture-set version; every fixture is complete or an
explicit base-plus-delta, and expected feeds are directly compared in canonical
descending order. V4 always asserts the 50th/51st boundary and `_id` tie-break;
V6 shares final-state equality, and live no-torn observation uses the shared
Q14 observer, with each direction naming its own atomic group. [`research-semantic-test-vectors.md`](../../research/skip-convex-integration/research-semantic-test-vectors.md)
is the rationale and coverage map.

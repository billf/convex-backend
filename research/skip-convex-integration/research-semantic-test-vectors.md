---
title: Shared semantic test vectors
type: research-note
status: active
direction: cross-cutting
date: 2026-09-14
related_plans:
  - 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
  - 2026-09-10-1854-feat-skip-data-sync-push-source-spike-plan.md
---

# Shared semantic test vectors (versioned data + expected results)

Turns the fixture contract into versioned data plus expected canonical
results — not only prose. All four spikes consume the same mutations and
expected outcomes; each keeps its independent oracle but proves the same
semantics. Fixture base gap: tutorial `schema.ts:4-10` has only
`messages{user,body}+by_user`, `users{name}+by_name` — rooms/memberships/
likes + `by_room_user`/`by_room`/`by_message` are app-layer additions
(`research-poc-vehicle-and-harness.md:48-55`; 1c U5 `...1854...:600-606`).

## Vector catalog (canonical projection throughout)

Each vector is either a **complete fixture** (all rows listed) or an
**explicit delta over a named base fixture** (base + added/removed rows).
"Minimal rows" below never assumes ambient rows: V1's room/message/user/
membership and V6's room/membership/message/like are listed in full. Compare
the **descending canonical output directly** — no chronological
renormalization before comparison (display order is a viewer concern, not an
oracle concern).

| # | Vector | Fixture (complete) | Mutation | Expected canonical result |
|---|---|---|---|---|
| V1 | Dangling sender | 1 room, 1 user + active membership, 1 msg w/ sender | delete user | message retained, `sender: null`, included iff membership active (D2 AE7 `...1702...:224-228`; 1c U5 `...1854...:610`; shared AE4 `...1159...:196-199`) |
| V2 | Active/inactive membership | 1 room, 2 users + memberships, 1 msg each | flip `active` | only active sender's message in feed (1c U5 `...1854...:611`; 1a AE1 `...1509...:138-141`; D2 AE1 `...1702...:190-194`; 1c AE2 `...1854...:191-194`) |
| V3 | Like add/remove | 1 room + membership + msg + 0..2 likes | add / delete like / delete liked-user | `likeCount` 0→1→0; liked-user delete keeps count (1a AE8 `...1509...:171-175`; 1c U5 `...1854...:611,614`; 1c AE1 `...1854...:185-189`) |
| V4 | 50-row boundary | 1 room + memberships + 51 msgs, distinct ts + one `_id`-tiebreak pair | — (read) | latest 50 by `(desc,desc)` compared descending, 51st excluded (contract `...1159...:91`; 1c U5 `...1854...:613`) |
| V5 | Deletes | 1 room + users + memberships + 2 msgs + like | delete each kind | message delete removes row + count; like delete decrements; user delete → `sender: null`; membership delete/deactivate excludes (1b AE3 `...1843...:171-174`; 1a AE4 `...1509...:151-160`; 1c R14 `...1854...:88`; D2 R13 `...1702...:101`) |
| V6 | Atomic membership+like txn | 1 room + membership + msg + like (all active/present) | single txn flips membership + adds like | settled final result is common to all four (feed reflects both changes, deep-equal to oracle); **no-torn-live-publication** stays direction-specific until 1b has matching coverage (1b observes swaps, not Transitions — its torn-observation point differs) (shared AE1 `...1159...:184-187`; 1a AE1; D2 AE1; 1c AE2; 1c U4 `...1854...:583`) |

Gap: no 1a/1b/1c/D2 acceptance example explicitly asserts V4's 51st-exclusion
+ tiebreak — U5's scenario covers it; consider a dedicated AE.

## AE coverage matrix

V1: D2 AE7, 1c U5, shared AE4. V2: 1a AE1, D2 AE1, 1c AE2. V3: 1a AE8, 1c AE1,
1c U5. V4: 1c U5 only. V5: 1b AE3, 1a AE4/AE8, 1c R14, D2 R13. V6: shared AE1,
1a AE1, D2 AE1, 1c AE2, 1c U4.

## Versioning + manifest parity

Mirror 1c's fixture discipline (`...1854...:304-322,532,569,634,655`:
`testdata/data_sync_stream/v1/manifest.json`, backend-canonical vs
adapter-vendored byte-parity). Major = query/predicate/projection/order/
limit/index-set change (incl. any future `sender: null` vs `"Unknown"`-class
flip); minor = added rows/vectors, new fault case, doc clarification. Pin the
vector-set version in the manifest; the harness asserts it.

## Sizing rule

Completeness over minimalism: every vector lists its full fixture (or names
its base + delta) — typically 2–7 rows (V4: exactly 51 messages plus their
room/memberships). Scaling N stays separate (1c `...1854...:467`:
N=100/1000/10000, K=1/10/100, F=1/10/100, ≥3 geometric points per order of
magnitude).

## Open questions

- Who owns the canonical v1 corpus first — backend U3 or adapter U4
  (`...1854...:730-734` fixture conflict, KTD6 vs P/Q fixtures)?
- Do tutorial UDF additions violate 1a/1b no-backend-change
  (`...1159...:264`; `research-poc-vehicle-and-harness.md:54-55`)?
- Dedicated AE for V4, or is U5's scenario sufficient?

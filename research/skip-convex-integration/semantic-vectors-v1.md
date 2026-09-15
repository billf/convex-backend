---
title: Shared semantic fixture corpus v1
type: fixture-specification
status: active
version: 1.0.0
date: 2026-09-14
---

# Shared semantic fixture corpus v1

This is the versioned manifest and canonical data source for V1–V6. A runner
must preserve these IDs, timestamps, operation order, and expected output; it
may translate the notation into its fixture language but may not generate
additional ambient rows. A major version changes the predicate, projection,
order, limit, or static index set. A minor version may add vectors or rows.

| Manifest field | Value |
|---|---|
| `fixtureSetVersion` | `1.0.0` |
| Static indexes | `memberships.by_room_user[room,user]`, `messages.by_room[room]`, `messages.by_sender[sender]`, `likes.by_message[message]` |
| Canonical output | Descending `(_creationTime, _id)`, active membership required, limit 50, nullable sender, exact like count |
| Required vectors | V1, V2, V3, V4, V5, V6 |

## Fixture notation

`R(id,name)`, `U(id,name)`, `M(id,room,user,active)`,
`Msg(id,time,room,sender,body)`, and `L(id,message,user)` are complete rows.
`Out(...)` is the exact canonical projection in descending order. A message in
an `Out` row has `{_id, _creationTime, room, body, sender, likeCount}`; its
sender is `null` when the referenced `U` row is absent. No row not written
below exists.

## V1 — dangling sender

Base: `R(r,"room")`, `U(u,"Ada")`, `M(mu,r,u,true)`,
`Msg(a,10,r,u,"one")`.

Delta: delete `U(u,"Ada")`.

Expected: `Out(a,10,r,"one",null,0)`.

## V2 — active membership

Base: `R(r,"room")`, `U(a,"Ada")`, `U(b,"Bea")`,
`M(ma,r,a,true)`, `M(mb,r,b,false)`, `Msg(a1,20,r,a,"a")`,
`Msg(b1,19,r,b,"b")`.

Expected base: `Out(a1,20,r,"a",{_id:a,name:"Ada"},0)`.

Delta: set `M(ma,r,a,false)` and `M(mb,r,b,true)`.

Expected delta: `Out(b1,19,r,"b",{_id:b,name:"Bea"},0)`.

## V3 — like add, removal, and dangling liked user

Base: `R(r,"room")`, `U(a,"Ada")`, `U(b,"Bea")`, `U(c,"Cy")`,
`M(ma,r,a,true)`, `Msg(a1,30,r,a,"liked")`.

Expected base: `Out(a1,30,r,"liked",{_id:a,name:"Ada"},0)`.

Delta 1: add `L(l1,a1,b)`.

Expected delta 1: `Out(a1,30,r,"liked",{_id:a,name:"Ada"},1)`.

Delta 2: delete `L(l1,a1,b)`.

Expected delta 2: `Out(a1,30,r,"liked",{_id:a,name:"Ada"},0)`.

Delta 3: add `L(l2,a1,c)`, then delete `U(c,"Cy")`.

Expected delta 3: `Out(a1,30,r,"liked",{_id:a,name:"Ada"},1)`.

## V4 — exact 50-row boundary and ID tie

Base rows shared by every message: `R(r,"room")`, `U(a,"Ada")`, and
`M(ma,r,a,true)`. The following is the complete message fixture, where every
row has `room:r`, `sender:a`, `body:"message-<id>"`, no likes, and the shown
creation time:

`m51@51, m50@51, m49@49, m48@48, m47@47, m46@46, m45@45, m44@44, m43@43,
m42@42, m41@41, m40@40, m39@39, m38@38, m37@37, m36@36, m35@35, m34@34,
m33@33, m32@32, m31@31, m30@30, m29@29, m28@28, m27@27, m26@26, m25@25,
m24@24, m23@23, m22@22, m21@21, m20@20, m19@19, m18@18, m17@17, m16@16,
m15@15, m14@14, m13@13, m12@12, m11@11, m10@10, m09@9, m08@8, m07@7,
m06@6, m05@5, m04@4, m03@3, m02@2, m01@1`.

Expected exact descending IDs: `m51, m50, m49, m48, m47, m46, m45, m44,
m43, m42, m41, m40, m39, m38, m37, m36, m35, m34, m33, m32, m31, m30, m29,
m28, m27, m26, m25, m24, m23, m22, m21, m20, m19, m18, m17, m16, m15, m14,
m13, m12, m11, m10, m09, m08, m07, m06, m05, m04, m03, m02`. Each expected
row has sender `{_id:a,name:"Ada"}` and `likeCount:0`. `m01` is the exact
51st qualifying row and must be excluded. The equal-time pair proves the
descending `_id` tie-break: `m51` precedes `m50`.

## V5 — deletes

Base: `R(r,"room")`, `U(a,"Ada")`, `U(b,"Bea")`, `M(ma,r,a,true)`,
`M(mb,r,b,true)`, `Msg(a1,40,r,a,"a")`, `Msg(b1,39,r,b,"b")`,
`L(l1,a1,b)`.

Expected base: `Out(a1,40,r,"a",{_id:a,name:"Ada"},1)`, then
`Out(b1,39,r,"b",{_id:b,name:"Bea"},0)`.

Independent deltas and expected outcomes: delete `Msg(a1,...)` removes `a1`
and its count; delete `L(l1,...)` changes `a1` to count zero; delete
`U(a,...)` retains `a1` with sender `null`; delete or deactivate `M(ma,...)`
excludes `a1`.

## V6 — atomic membership plus like transaction

Base: `R(r,"room")`, `U(a,"Ada")`, `U(b,"Bea")`, `M(ma,r,a,true)`,
`Msg(a1,50,r,a,"atomic")`, `L(l1,a1,b)`.

Single transaction delta: set `M(ma,r,a,false)` and add `L(l2,a1,b)`.

Expected settled final output: `Out()` (the inactive membership excludes the
message, regardless of its now-two like rows). Every direction compares this
same final state to its native oracle. Its live no-torn observation remains
direction-specific.

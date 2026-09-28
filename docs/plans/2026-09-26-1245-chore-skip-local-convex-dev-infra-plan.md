---
title: Skip Local Convex Development Infrastructure - Plan
type: chore
date: 2026-09-26
topic: skip-local-convex-dev-infra
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-split
execution: code
split_from: 2026-09-11-1159-feat-skip-shared-prerequisites-plan.md
ste_companion: 2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.ste.md
execution_started: null
execution_status: not-started
units:
  I1: pending
  I2: pending
  I3: pending
  I4: pending
  I5: pending
---

# Skip Local Convex Development Infrastructure - Plan

This plan is authoritative. A Simplified Technical English companion, [the STE version](2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.ste.md), restates it for easier reading and translation; regenerate the companion after every change here, and use this plan wherever the two differ.

This plan was split out of
[the Skip Shared Prerequisites plan](2026-09-11-1159-feat-skip-shared-prerequisites-plan.md)
on 2026-09-26. That plan's U11 and U15 each name the identical unmet
requirement — "a live local Convex deployment this environment doesn't
have" — as their main remaining blocker; the other named units (Q9,
Q14, AE4, AE6, AE7, AE12, AE13, F1-F5, P3, P4, P9) are
already satisfied by code sitting in the `skip` worktree. Standing up
that deployment and adapting the fixture loader to target it are not
themselves part of proving Q or P; they are prerequisites both units
currently assume exist. This plan supplies those prerequisites. U11
and U15 stay in the parent plan and consume this plan's
Definition of Done as a dependency; they do not move here.

---

## Goal Capsule

- **Objective:** A reachable local Convex deployment plus a built Skip
  WASM runtime, both addressable at fixed loopback URLs, such that the
  parent plan's U11 (`reference:snapshot`) and U15 (`reference:revision`)
  can run against something real instead of stopping at "no deployment."
- **Means:** Use `convex-backend`'s own `Justfile` dev workflow
  (`run-local-backend`, `generate-admin-key`, `convex`) rather than the
  self-hosted Docker Compose path — this repo already builds the backend
  from source and the Docker path would add a daemon dependency this
  environment doesn't have running. Reuse the parent plan's own
  toolchain finding for `@skipruntime/wasm` (built via `container` in
  place of Docker) instead of re-deriving it.
- **Product authority:** Derived directly from the parent plan's U11 and
  U15 unit definitions and its Verification Contract's "Skip runtime
  prerequisite" and "Snapshot reference" / "Revision reference" rows.
  Not separately brainstormed.
- **Open blockers:** None known going in. Every command below has
  already been located in this repo's `Justfile` and `BUILD.md`; nothing
  here needs a new tool or a new external service. The existing fixture
  loader needs the narrow self-hosted targeting change specified in I2.
- **Stop conditions:** Stop and escalate to the parent plan's Goal
  Capsule if a unit here turns out to need a Skip runtime, FFI, or
  convex-backend code change (P8 in the parent plan) — this plan only
  wires up existing tooling, it does not extend either codebase. Stop if
  the Skiplang toolchain cannot be built by any documented path; do not
  substitute a mock runtime (parent plan, same constraint, restated
  here for I3).
- **Execution profile:** Two repositories touched: `convex-backend`
  (running the existing local backend, no code changes) and
  `convex-tutorial` (pushing the existing `proofVehicle` fixture and
  changing only its loader CLI and focused test). The `skip` worktree's
  build is exercised but not edited. No pushes to any remote without
  explicit user approval.

---

## Product Contract

### Summary

Stand up, once, the local Convex deployment and Skip WASM runtime that
the parent plan's U11 and U15 need to run against a real system instead
of a mock. It makes one compatibility change to the fixture loader and
tests that change; it asserts no Q/P correctness claims of its own.
Its Definition of Done is "the deployment and runtime
exist, are reachable, and hold the expected fixture" — the parent
plan's own reference scripts remain the thing that proves Q and P.

### Problem Frame

The parent plan's frontmatter already states, unit by unit, that its
Q/P code dependencies for U11 (U3, U5, U7-U10, U12) and for U15 (U11,
U13, U14) are done. What remains is local infrastructure and its
fixture-loader connection: no local backend has
ever been started in this environment, `convex-tutorial` has never been
pushed anywhere (no `.env.local` exists), and the Skiplang toolchain's
build path (LLVM 20 + matching `wasm-ld`, or the `container`-based
substitute the parent plan's U3 already found) has not been run to
completion end-to-end. Treating this as a fifth implementation unit
inside the parent plan would conflate "prove Q/P" work with "make a
server exist" work — this split keeps the parent plan's Definition of
Done about correctness claims, and puts the infrastructure prerequisite
in its own reviewable, independently-useful place (anyone else building
against this repo's local backend needs the same three things: a
running backend, a pushed fixture, and a built Skip runtime).

### Requirements

**Convex local backend**

- I1a. `local_backend` builds and runs from source via
  `just run-local-backend --interface 127.0.0.1`, listening on
  `127.0.0.1:3210` (RPC) and `127.0.0.1:3211` (HTTP actions), using the existing `Justfile`
  recipes (`init-instance-secret`, `generate-admin-key`) with no new
  secrets material introduced.
- I1b. The backend survives a `reset-local-backend` / restart cycle
  without manual intervention, so a failed run can be retried cleanly.

**Fixture deployment**

- I2a. `convex-tutorial`'s `proofVehicle` functions push cleanly to the
  running local backend via `npx convex dev --once` with `--admin-key`
  and `--url` passed explicitly from the backend checkout's key recipe
  (the `just convex` wrapper only resolves inside `convex-backend`),
  producing a `.env.local` whose `CONVEX_URL` the reference source
  uses. The loader receives the same URL in its process environment;
  `tsx` does not load `.env.local` automatically.
- I2b. `PROOF_VEHICLE_FIXTURE=1` is set on the deployment (`npx convex
  env set`), matching the parent plan's Verification Contract row for
  the snapshot reference run.
- I2c. The parent plan's KTD3 four-thing coupling (function names, `allSelectedRows`'s
  tagged row shape, the corpus file, the loader CLI's JSON output) is
  confirmed live-reachable: the loader CLI runs against this
  deployment and produces a label-to-ID JSON map. The tutorial parity
  manifest's `fixtureSetVersion` matches the vendored Skip parity manifest.
- I2d. The loader CLI uses one self-hosted target for its reads and all
  imports: explicit `CONVEX_URL` and `PROOF_VEHICLE_ADMIN_KEY` process
  variables, with the URL matching the generated `.env.local` and the
  key supplied by `generate-admin-key`. It passes `--url`
  and `--admin-key` to each `npx convex import`, without
  `--deployment`. It fails before importing if either value is missing.

**Skip WASM runtime**

- I3a. `@skipruntime/wasm` builds successfully (`npm run build -w
  @skipruntime/wasm` in
  `~/src/skip/.worktrees/feat-skip-shared-prereqs`) using the toolchain
  path the parent plan's U3 already established (`container`-based build in
  place of a native LLVM 20 + `skargo` install), recorded by version /
  image reference the way U3 already does.
- I3b. A trivial `initService` smoke (start the runtime, register one
  resource, observe one update, shut down cleanly) passes outside any
  test file, to separate "the runtime builds and runs" from "Q's
  reference service is correct" (the latter stays U11/U15's job).

**Process and sandbox readiness**

- I4a. The backend (I1) and `convex dev` in watch mode (started after
  I2's one-shot push) are documented as long-lived
  processes that must be running concurrently with any U11/U15 run;
  this plan states how to start and confirm each is up, not how to
  keep them up across sessions.
- I4b. Q's reference service (U11's `reference/service.ts`) needs a
  loopback bind; this plan proves that bind succeeds under this
  environment's sandbox with a confirmed loopback permission. This
  prevents a second permission blocker when U11 begins. A bypass —
  running outside the sandbox or with the sandbox disabled — does not
  satisfy this requirement.

### Acceptance Examples

- AE1. Given a clean checkout with no `convex_local_storage/` and no
  `convex_local_backend.sqlite3`, when
  `just run-local-backend --interface 127.0.0.1` runs, then the process
  listens on `127.0.0.1:3210` and `127.0.0.1:3211` only, and
  `just generate-admin-key` returns a non-empty key derived from the
  freshly-generated instance secret.
- AE2. Given that running backend, when `npx convex dev --once` runs
  from the fixture worktree with I2's explicit admin key and URL flags,
  then it pushes with no errors and writes a `.env.local` containing
  `CONVEX_URL=http://127.0.0.1:3210`.
- AE3. Given the pushed deployment, when the tutorial's loader CLI
  (KTD5) is run against it, then its JSON output is a label-to-ID map;
  the tutorial parity manifest's `fixtureSetVersion` matches the vendored Skip
  parity manifest at `skip: examples/convex_proof_harness/testdata/v1.parity.json`.
- AE4. Given the `feat-skip-shared-prereqs` Skip worktree, when
  `npm run build -w @skipruntime/wasm` is run using the `container`-based
  path, then it exits 0 and leaves a usable `dist/`, and a follow-up
  `initService` smoke script starts, registers one resource, observes
  one update, and shuts down without a hung process.
- AE5. Given both the backend and the Skip runtime running, when U11's
  `reference/service.ts` (once written) attempts its loopback bind,
  then the bind succeeds under the in-sandbox setting this plan's I4
  confirmed; an EPERM there fails this plan rather than passing with
  a documented bypass.

### Scope Boundaries

- No changes to `local_backend`, `convex-tutorial`'s `proofVehicle`
  functions or corpus, or any `skip` source file. The one code
  exception is `convex-tutorial/scripts/proof-vehicle-load.ts` and its
  focused test, to let existing import logic target the self-hosted
  backend with the same URL used for reads.
- No production or hosted deployment. Loopback only, matching every
  other unit's loopback-only constraint in the parent plan.
- No writing of U11's or U15's actual reference scripts
  (`reference/{service,source,run}.ts`) — those stay the parent plan's
  units and consume this plan's Definition of Done as their dependency.
- No push to any git remote in any of the three repositories without
  explicit user approval.

### Deferred to Follow-Up Work

- Writing and passing U11's and U15's own test scenarios — unchanged,
  still owned by the parent plan.
- Any persistent/production hosting of the local backend (fly.io,
  Railway, S3 storage, Postgres/MySQL backing) — self-hosting's
  advanced configuration docs cover that ground if it's ever needed;
  nothing here requires it.
- Automating "start the backend and `convex dev` on every session" —
  out of scope; this plan documents the manual commands, not a
  supervisor process.

### Sources / Research

- `docs/plans/2026-09-11-1159-feat-skip-shared-prerequisites-plan.md`
  — U11, U15, and the Verification Contract rows this plan exists to
  unblock.
- `BUILD.md` — `just install-js`, `just run-local-backend`, demo
  provisioning walkthrough.
- `Justfile` — `run-local-backend`, `generate-admin-key`,
  `init-instance-secret`, `convex`, `reset-local-backend` recipes (the
  concrete commands this plan's units run).
- `self-hosted/README.md` — the Docker Compose alternative, considered
  and rejected in KTD1 below in favor of the `Justfile` path already
  native to this repo.
- `~/src/skip/INSTALL.md` — Skiplang toolchain dependencies (LLVM 20,
  matching `wasm-ld`, TypeScript 5.7+) and the native build path.
- `~/src/skip/Dockerfile` — the containerized build path the parent
  plan's U3 already used via Apple's `container` CLI in place of
  Docker.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Use the `Justfile` dev workflow, not self-hosted Docker
  Compose.** `convex-backend` already builds `local_backend` from
  source with `just run-local-backend`, and `just convex`/
  `just generate-admin-key` already wrap the admin-key and URL
  plumbing the self-hosted Docker path exists to avoid hand-rolling.
  Docker Compose would add a `docker compose` daemon dependency this
  environment doesn't have (only Apple's `container` CLI is present,
  no Docker daemon); the `Justfile` path needs only `cargo`, already
  installed and toolchain-pinned via `rust-toolchain`. Governs I1, I2.
- KTD2. **The generated instance secret and admin key are dev-only and
  loopback-scoped.** `Justfile`'s own comment states the default admin
  key is safe "as long as the backend is running locally"; this plan
  treats that as given and does not add key rotation, since the parent
  plan's units never serve this backend beyond loopback. Governs I1.
- KTD3. **Reuse, don't re-derive, the parent plan's U3 toolchain
  finding for `@skipruntime/wasm`.** The prior session already
  unblocked the Skiplang toolchain build via `container` in place of a
  native LLVM 20 + `wasm-ld` install; this plan's I3 repeats and
  verifies that path end-to-end (through a runtime smoke, not just a
  build exit code) rather than treating it as a fresh unknown. If that
  path no longer works, this plan escalates under the parent plan's
  stop condition rather than substituting a mock. Governs I3.
- KTD4. **Long-lived processes are documented, not embedded.** The
  backend and `convex dev` must stay running for the full duration of
  any U11/U15 run; this plan's I4 states how to start and confirm them
  (each as its own long-lived process, started ahead of time: the
  backend from I1, and `convex dev` in watch mode without `--once`
  started after I2's one-shot push — via
  `run_in_background` or the user's own terminal) rather than having
  any single test command spawn and tear them down, since U11/U15's
  scripts assume a URL that's already live. Governs I1, I4.
- KTD5. **The fixture loader uses the self-hosted URL and admin key for
  both read and import operations.** The explicit `--url`/
  `--admin-key` development path writes `CONVEX_URL` but removes
  `CONVEX_DEPLOYMENT`; the current loader requires that removed
  variable and passes `--deployment` to imports. The Convex CLI does
  not allow `--deployment` with self-hosted credentials. I2 updates
  only the loader and its focused test to pass the same URL and key to
  every import, preserving the existing corpus and label binding.
  Governs I2.

### High-Level Technical Design

```mermaid
flowchart TB
  A[just install-js / cargo toolchain] --> B[just run-local-backend --interface 127.0.0.1<br/>127.0.0.1:3210 / :3211]
  B --> C[just generate-admin-key]
  C --> D[npx convex dev --once<br/>in fixture worktree]
  D --> E[proofVehicle fixture pushed<br/>.env.local written]
  E --> F[npx convex env set<br/>PROOF_VEHICLE_FIXTURE=1]
  F --> M[loader uses same URL and admin key<br/>for reads and imports]
  G[feat-skip-shared-prereqs worktree<br/>container-based build] --> H[npm run build -w @skipruntime/wasm]
  H --> I[initService smoke]
  M --> J[Deployment + runtime reachable]
  I --> J
  J --> K[Parent plan U11: reference:snapshot]
  K --> L[Parent plan U15: reference:revision]
```

### Assumptions

- `cargo`, `just`, `node` 22.x, and `npm` are already installed and
  correctly versioned in this environment (confirmed: rust
  `nightly-2026-06-28` with `wasm32-wasip1` active via
  `rust-toolchain`, node 22.22.2, `just` and `container` on `PATH`).
- No Docker daemon is available or needed; every command in this plan
  either runs natively or through the already-proven `container` CLI
  substitute.
- The `skip` worktree at `feat/skip-shared-prereqs` (where U1-U16's
  code already lives) is the one this plan's I3/I5 build and smoke-test
  against; this plan does not create a new worktree.

---

## Implementation Units

### I1. Build and run the Convex local backend

- **Goal:** A running `local_backend` reachable at fixed loopback URLs.
- **Requirements:** I1a, I1b.
- **Dependencies:** None.
- **Files:** None changed; runs existing `Justfile` recipes.
- **Approach:**
  1. `npm clean-install --prefix scripts && just install-js` (idempotent
     if already done).
  2. `just run-local-backend --interface 127.0.0.1` as a long-lived
     background process; confirm both `127.0.0.1:3210` and `:3211`
     accept connections and neither binds a non-loopback interface.
  3. Confirm `just generate-admin-key` returns a stable, non-empty key
     across repeated calls (reuses the persisted secret, per KTD2).
  4. Exercise `just reset-local-backend` once against a throwaway run
     to confirm a clean restart works (I1b), then start the real run
     fresh.
- **Test scenarios:**
  - Backend starts with no prior `convex_local_storage/`.
  - A second `just run-local-backend --interface 127.0.0.1` after
    `reset-local-backend` starts clean with a freshly generated secret
    and key.
  - `generate-admin-key` is idempotent within one storage directory.
- **Verification:** `curl` (or equivalent) against `127.0.0.1:3210` and
  `:3211` succeeds while the process runs, and both listeners are
  loopback-only; `just generate-admin-key` exits 0 with non-empty
  output.

### I2. Push the proof-vehicle fixture to the running backend

- **Goal:** `convex-tutorial`'s `proofVehicle` functions live on the
  backend from I1, with the fixture flag set.
- **Requirements:** I2a, I2b, I2c, I2d.
- **Dependencies:** I1.
- **Files:** `/Users/bill/src/convex-tutorial/.worktrees/feat-skip-shared-prereqs/.env.local`
  (generated, not hand-written),
  `scripts/proof-vehicle-load.ts`, and
  `scripts/proof-vehicle-load.test.ts` in that worktree.
- **Approach:**
  1. From the fixture worktree
     (`/Users/bill/src/convex-tutorial/.worktrees/feat-skip-shared-prereqs`,
     the checkout whose `convex/` holds `proofVehicle/`), run
     `npx convex dev --once` with the backend's key and URL passed
     explicitly:
     `npx convex dev --once --admin-key "$(just --justfile
     ~/src/convex-backend/Justfile generate-admin-key)" --url
     http://127.0.0.1:3210`.
     The `just convex` wrapper recipe is not used here: `just` resolves
     its command file upward from the invocation directory, so it finds
     no `Justfile` from a sibling checkout, and the recipe's inner key
     lookup resolves the same way.
  2. `npx convex env set PROOF_VEHICLE_FIXTURE 1` with the same explicit
     key and URL flags, against the same deployment.
  3. Update the loader's self-hosted path to require `CONVEX_URL` and
     `PROOF_VEHICLE_ADMIN_KEY` in its process environment. Pass that URL and key
     as `--url` and `--admin-key` on every `npx convex import` call;
     do not pass `--deployment`. Reject a missing URL or key before
     any import, and test the constructed import arguments without
     starting a deployment.
  4. Run the tutorial's loader CLI against this live deployment with
     `CONVEX_URL=http://127.0.0.1:3210` and
     `PROOF_VEHICLE_ADMIN_KEY="$(just --justfile ~/src/convex-backend/Justfile generate-admin-key)"`
     set for this process, for example `npm run proof-vehicle-load -- V1`.
     Verify that the URL matches the generated `.env.local`. Then
     parse its label-to-ID JSON map. Compare `fixtureSetVersion` in
     `convex-tutorial: convex/proofVehicle/corpus/v1.parity.json` with
     `skip: examples/convex_proof_harness/testdata/v1.parity.json`
     in the Skip worktree.
- **Test scenarios:**
  - Push succeeds with no schema or function errors.
  - `PROOF_VEHICLE_FIXTURE` reads back as `1` via `npx convex env get`
    with the same explicit key and URL flags.
  - The loader passes the read URL and admin key to each import and
    rejects a missing value before writing. No import uses
    `--deployment` on the self-hosted path.
  - Loader CLI emits a label-to-ID map, and the tutorial and Skip
    parity manifests have the same `fixtureSetVersion` (I2c);
    a mismatch fails this unit before U11 starts.
- **Verification:** `npx convex env get PROOF_VEHICLE_FIXTURE` (same
  explicit flags) returns `1`; the focused loader test passes, the
  loader CLI exits 0 with a label-to-ID JSON map against the local
  backend, and the two parity manifest versions match.

### I3. Build and smoke-test the Skip WASM runtime

- **Goal:** `@skipruntime/wasm` built and confirmed runnable, separate
  from any correctness claim about Q's reference service.
- **Requirements:** I3a, I3b.
- **Dependencies:** None (buildable in parallel with I1/I2).
- **Files:** None changed in `skip`; build artifacts only.
- **Approach:**
  1. Reuse the `container`-based toolchain path the parent plan's U3
     already established; record the image/toolchain version the way
     U3's frontmatter note already does, so a later drift is
     detectable.
  2. `npm run build -w @skipruntime/wasm` in
     `~/src/skip/.worktrees/feat-skip-shared-prereqs`.
  3. Write and run a throwaway smoke script (not committed as a test —
     this is infra verification, not a Q test scenario) that calls
     `initService`, registers one resource, writes one value, observes
     one update, and shuts down.
- **Test scenarios:**
  - Build exits 0 and produces `dist/`.
  - Smoke script observes exactly one update and exits cleanly with no
    hung handles.
- **Verification:** `npm run build -w @skipruntime/wasm` exits 0; smoke
  script exits 0.

### I4. Confirm sandbox/process readiness for the reference service

- **Goal:** Document what U11's `reference/service.ts` needs from this
  environment's sandbox before that unit is attempted, so it fails once
  (here, with a named cause) rather than a second time (there, as a
  generic EPERM).
- **Requirements:** I4a, I4b.
- **Dependencies:** I1, I3.
- **Files:** None changed; this plan's I4 outcome records the finding in place.
- **Approach:**
  1. Start a throwaway Express listener bound explicitly to
     `127.0.0.1` on an unused port, the same way U11's `service.ts`
     plans to, under this environment's default sandbox.
  2. First list the effective sandbox settings from this session's
     sandbox documentation to confirm the exact loopback-bind key name
     and whether it needs a restart; then test the throwaway listener
     with the narrow loopback permission first. If the bind fails under
     every in-sandbox setting, fail this unit and escalate to the
     parent plan — do not record running outside the sandbox or with
     it disabled as the documented path.
  3. Record only the observed working in-sandbox option as the
     documented path U11 follows,
     rather than rediscovering it mid-U11.
- **Test scenarios:**
  - The throwaway listener binds successfully under the confirmed
    setting.
  - A non-loopback bind attempt (e.g., `0.0.0.0`) is confirmed to still
    fail/refuse, matching every other unit's loopback-only constraint.
- **Verification:** A throwaway `127.0.0.1`-bound listener starts and
  accepts a connection under the documented setting.

### I5. End-to-end reachability smoke

- **Goal:** One check that all three pieces (backend, fixture,
  runtime) are simultaneously reachable, as the actual gate this plan
  exists to close.
- **Requirements:** All of I1-I4.
- **Dependencies:** I1, I2, I3, I4.
- **Files:** None changed.
- **Approach:** With the backend (I1) and watch-mode `convex dev`
  (started after the I2 push) running and
  the Skip runtime built (I3) under the confirmed sandbox setting (I4),
  run a minimal script that: subscribes to the tutorial's
  `allSelectedRows` query via `ConvexClient` against the live backend,
  starts a Skip `initService` instance, and confirms both are
  observably alive at the same time (one read from each, no
  correctness comparison — that's U11's job).
- **Test scenarios:**
  - Both the Convex read and the Skip read succeed in the same process
    run.
  - The script exits 0 and leaves no orphaned process.
- **Verification:** Smoke script exits 0.

---

## Verification Contract

| Scope | Command | Proves |
|---|---|---|
| Backend up | `just run-local-backend --interface 127.0.0.1` (background) + loopback-only listener checks | I1 |
| Fixture pushed | `npx convex dev --once` with explicit key/URL flags from the fixture worktree, then `npx convex env get PROOF_VEHICLE_FIXTURE` with the same flags; focused loader test and live loader run using the same URL/key | I2 |
| Skip runtime | `npm run build -w @skipruntime/wasm` in `~/src/skip/.worktrees/feat-skip-shared-prereqs`, then the I3 smoke script | I3 |
| Sandbox readiness | throwaway `127.0.0.1` bind under the confirmed sandbox setting | I4 |
| Reachability | I5's combined smoke script | I5, this plan's Definition of Done |

---

## Definition of Done

- `just run-local-backend --interface 127.0.0.1` serves a fresh
  deployment reachable on `127.0.0.1:3210`/`:3211` only.
- `convex-tutorial`'s `proofVehicle` fixture is pushed to that
  deployment with `PROOF_VEHICLE_FIXTURE=1` set. The loader CLI emits
  its label-to-ID map, and the tutorial and Skip parity
  manifests have the same `fixtureSetVersion`. The loader's imports and
  reads target the same self-hosted URL.
- `@skipruntime/wasm` is built and passes a runtime smoke independent
  of any Q test.
- U11's `reference/service.ts` loopback bind is proven to succeed under
  the confirmed in-sandbox setting, not left to be rediscovered
  mid-U11; a bypass does not satisfy this plan.
- No code in `local_backend` or `skip` was changed. In
  `convex-tutorial`, only the loader CLI and its focused test changed;
  the fixture functions and corpus remain as they were.
- The parent plan's U11 can begin writing and running
  `reference/{service,source,run}.ts` against a real, already-reachable
  deployment; U15 follows once U11 passes.

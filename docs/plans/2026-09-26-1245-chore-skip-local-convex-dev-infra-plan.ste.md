---
title: Skip Local Convex Development Infrastructure - STE Version
type: chore
date: 2026-09-28
topic: skip-local-convex-dev-infra
source_plan: 2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md
---

# Skip Local Convex Development Infrastructure

## Purpose

This document gives the STE version.

It covers the local infrastructure plan.

The source plan is authoritative.

If this document differs from the source plan, use the source plan.

Use the source plan for exact commands, file paths, and the diagram.

The plan builds a local Convex deployment and a Skip runtime.

The plan also updates the fixture loader for the local deployment.

Two other units in the shared prerequisites plan need this deployment and this runtime.

Those units are U11 and U15.

## Regeneration and Staleness

Regenerate this document after every change to the source plan.

Use the source plan as the only input authority.

Compare requirements, decisions, work units, verification, and completion rules after regeneration.

Do not keep a companion statement that the source plan no longer supports.

Run the STE checker on this document after each regeneration.

Run a symmetry review against the source plan when meaning changes.

## Why This Plan Exists

The shared prerequisites plan lists U11 and U15 as not started.

Both units need a live local Convex deployment.

The fixture loader also needs a change to use this deployment.

The other named units are already done as code.

Standing up a deployment is not a proof of correctness.

It is infrastructure that U11 and U15 assume already exists.

This plan supplies the infrastructure and updates the fixture loader.

U11 and U15 stay in the shared prerequisites plan.

They do not move into this plan.

The Definition of Done in this plan becomes a dependency for both.

## Objective

Give U11 and U15 a real local Convex deployment to run against.

Give U11 and U15 a built Skip runtime to run against.

Update the fixture loader to use the local deployment for reads and imports.

Bind both to fixed loopback addresses.

Prove the loopback bind that the reference service in U11 will need.

Do not add a correctness claim of its own.

The reference scripts in the shared prerequisites plan still prove Q and P.

## Stop Rules

Stop and escalate to the shared prerequisites plan under two conditions.

The first condition is a needed change to the Skip runtime or the FFI layer.

The second condition is a needed change to the Convex backend code.

This plan changes only the fixture loader and its focused test in the tutorial checkout.

It does not change the Convex backend or the Skip runtime.

Stop if the Skip language toolchain fails to build by any documented method.

Do not use a mock runtime in place of a failed build.

## Product Contract

### Requirements

**The Convex local backend**

Build and run `local_backend` from source.

Use the existing `just run-local-backend` command.

Listen on `127.0.0.1` at port 3210 for RPC calls.

Listen on `127.0.0.1` at port 3211 for HTTP actions.

Use the existing key commands.

Add no new secret material.

Let the backend recover cleanly after a reset and a restart.

**The pushed fixture**

Push the `proofVehicle` functions from the tutorial checkout to the running backend.

Run this push with `npx convex dev --once`.

Pass the admin key and the URL as explicit flags.

The push writes a `.env.local` file.

The reference source uses the URL in that file.

Give the loader the same URL in its process environment.

Give the loader an admin key in its process environment.

The loader uses that URL and key for reads and all imports.

The loader does not use a deployment name for imports.

The loader stops before any import if the URL or key is missing.

Set `PROOF_VEHICLE_FIXTURE` to 1 on the deployment.

Run the loader script from the tutorial checkout against the deployment.

Check the source corpus version against the version stored in the Skip workspace.

**The Skip WASM runtime**

Build `@skipruntime/wasm`.

Use the container-based method the shared prerequisites plan already found.

Record the container image version used for the build.

Run a small smoke check after the build.

The smoke check starts the runtime, adds one resource, and reads one update.

Keep the smoke check separate from any correctness test of the reference service.

**Sandbox and process readiness**

Keep the backend running for the whole reference run.

Keep a watching `convex dev` process running for the whole reference run.

Start each process ahead of time.

Do not start them inside a single test command.

Prove that the loopback bind in the reference service succeeds.

Prove this under the sandbox loopback setting.

Do not accept a bind that only succeeds with the sandbox turned off.

### Acceptance Examples

Given a clean checkout, when the run-backend command runs, then the backend listens on both ports.

Given that clean checkout, the admin key command also returns a key.

Given the running backend, when the push command runs, then it writes the env file with no error.

Given the pushed deployment, when the loader script runs against it, then it returns a label-to-ID map.

The source corpus and the Skip parity manifest must have the same fixture set version.

Given the Skip workspace, when the WASM build runs through the container method, then the build exits clean.

Given that clean build, the smoke check also passes.

Given the running backend and the running runtime, when the reference service attempts its bind, then the bind succeeds.

This success happens under the sandbox setting.

### Scope Boundaries

Change no code in `local_backend`.

Change only the fixture loader and its focused test in the tutorial checkout.

Do not change the fixture functions or corpus.

Change no code in the Skip workspace.

Build no production or hosted deployment. Use loopback addresses only.

Write no part of the reference scripts for U11 or for U15.

Push no commit to any remote without the explicit approval of the user.

### Deferred Work

The test scenarios for U11 and for U15 stay deferred to the shared prerequisites plan.

Any hosted or production deployment stays deferred.

The self-hosting guide already covers that ground.

A supervisor process for the backend and for `convex dev` stays deferred.

## Main Technical Decisions

### KTD1: Use Just Commands, Not Docker

The backend builds from source with the run-backend command.

The just commands already wrap the admin key and the URL.

This environment has no Docker daemon.

It has only the container command.

The just commands need only `cargo`, which is already installed.

Use the just commands instead of the self-hosted Docker Compose path.

### KTD2: Treat the Key as Local Only

The generated secret and key are for local use only.

They are safe only while the backend serves loopback addresses only.

Add no key rotation.

No unit in this plan serves the backend past loopback.

### KTD3: Reuse the WASM Build Method

An earlier unit found a working build method for the WASM package.

That method uses the container command in place of a native compiler install.

This plan repeats that method and adds a runtime smoke check.

If that method stops working, escalate.

Do not build a new method here.

### KTD4: Document the Long Processes, Do Not Embed Them

The backend must run for the whole reference run.

The `convex dev` process must also run for the whole reference run.

Start each one as its own long process before any reference run starts.

Do not have one test command start and stop them.

The reference scripts expect a URL that is already live.

### KTD5: Use One Local Target for Reads and Imports

The local development command writes a URL to `.env.local`.

It removes the deployment name from that file.

The current loader requires a deployment name for imports.

The import command cannot use a deployment name with a local URL and admin key.

Update the loader to pass the same URL and key to every import.

Keep the existing corpus and label binding.

## Assumptions

`cargo`, `just`, `node`, and `npm` are already installed and correctly versioned.

The Rust toolchain already includes the WASM target this plan needs.

No Docker daemon is available.

The container command replaces it wherever needed.

The Skip workspace checkout already holds the code from the earlier sixteen units.

This plan builds and tests against that same checkout.

This plan creates no new checkout.

## Work Order

Build the backend first. This is unit I1.

Push the fixture and update its loader next. This is unit I2. It depends on I1.

Build the Skip runtime in parallel. This is unit I3. It has no dependency.

Check the sandbox setting next. This is unit I4. It depends on I1 and I3.

Run the full reachability check last. This is unit I5. It depends on I1 through I4.

## Work Units

### I1: Build and Run the Local Backend

Install the JavaScript dependencies.

Start `local_backend` from source as a long process.

Confirm both ports accept a connection.

Confirm the admin key command returns the same key on repeated calls.

Reset the backend once and confirm it restarts clean.

Test that the backend starts with no prior storage directory.

Test that a reset backend starts clean with a new secret and a new key.

### I2: Push the Fixture to the Running Backend

Push the `proofVehicle` functions with the explicit key and URL flags.

Set the fixture flag to 1 on the deployment.

Update the loader to require `CONVEX_URL` and `PROOF_VEHICLE_ADMIN_KEY`.

Pass these values as URL and admin key flags to each import.

Do not pass a deployment name to an import.

Test that the loader rejects a missing URL or key before an import.

Test the import arguments without a live deployment.

Run the loader against the deployment with explicit process variables.

Use the same URL that `.env.local` contains.

Get the admin key from the existing key command.

Read the label-to-ID map from the loader.

Compare the source corpus version with the Skip parity manifest version.

Test that the push completes with no schema error and no function error.

Test that the fixture flag reads back as 1.

Test that the source corpus and parity manifest versions match.

### I3: Build and Smoke-Test the Skip Runtime

Build `@skipruntime/wasm` through the container-based method.

Record the container image version used.

Run a smoke script that starts the runtime, adds one resource, and reads one update.

Test that the build exits with no error.

Test that the smoke script exits clean with no open process left running.

### I4: Confirm the Sandbox Setting

Start a throwaway listener bound to a loopback address.

The reference service will bind the same way.

Check the sandbox loopback setting first.

Test the listener under that setting.

If the bind fails under every in-sandbox setting, stop this unit and escalate.

Do not record a bypass as the working setting.

Record only the setting that actually works.

Test that the throwaway listener accepts a connection under the recorded setting.

Test that a non-loopback bind still fails.

Every other unit follows this same rule.

### I5: Run the End-to-End Reachability Check

Keep the backend and the watching `convex dev` process running.

Build the Skip runtime before this check.

Run the check under the confirmed sandbox setting.

Run a script that reads from the live backend and starts the Skip runtime in one process.

Read one value from the Skip runtime.

Make no correctness comparison here.

That check stays the job of U11.

Test that both reads succeed in the same run.

Test that the script exits clean with no orphan process.

## Verification Gates

Start the backend and confirm both ports accept a connection. This proves I1.

Push the fixture and read the fixture flag back.

Run the focused loader test and the live loader.

Compare the source corpus and parity manifest versions. This proves I2.

Build the Skip runtime and run its smoke script. This proves I3.

Bind the throwaway listener under the confirmed sandbox setting. This proves I4.

Run the combined reachability script. This proves I5.

It also proves the Definition of Done for this plan.

## Out of Scope

Do not change `local_backend`, the tutorial fixture functions or corpus, or the Skip workspace.

Change only the tutorial loader and its focused test.

Do not build a hosted or production deployment.

Do not write the reference scripts for U11 or for U15.

Do not build a process supervisor for the backend or for `convex dev`.

## Completion Rules

The backend serves a fresh deployment on both loopback ports.

The push of the fixture completes. This plan sets the fixture flag.

The loader reads and imports through the same local URL.

The loader returns a label-to-ID map.

The source corpus and parity manifest versions match.

This plan builds the Skip runtime, and it passes its own smoke check.

The confirmed sandbox setting proves the loopback bind of the reference service.

No code changed in `local_backend` or in the Skip workspace.

Only the tutorial loader and its focused test changed.

The tutorial fixture functions and corpus did not change.

U11 can start against a real, already-reachable deployment.

U15 follows after U11 passes.

# Skip local dev infrastructure

Scripts that stand up the local Convex deployment and Skip WASM runtime
that the Skip/Convex integration plans need to run against something
real. Built for
[`docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md`](../../docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md)
(I1-I5); reusable by any later plan that needs the same three things: a
running backend, a pushed fixture, and a built Skip runtime.

Both humans and agents should use these scripts rather than re-deriving
the underlying `just`/`npx convex`/`container` commands each time —
that's the whole point of this directory.

## Quick start

```sh
just skip-dev-up          # I1-I5, in order, idempotent
just skip-dev-status       # what's currently running, without changing anything
just skip-dev-down         # stop the backend (add --reset to also clear storage)
```

Or run the scripts directly:

```sh
scripts/skip-local-dev/up.sh
scripts/skip-local-dev/status.sh
scripts/skip-local-dev/backend-down.sh [--reset]
```

## What each script does

| Script | Unit | Does |
|---|---|---|
| `backend-up.sh` | I1 | Starts `local_backend` via `just run-local-backend --interface 127.0.0.1`, loopback-only, as a background process. Idempotent. |
| `backend-down.sh` | I1 | Stops it. `--reset` also runs `just reset-local-backend`. |
| `backend-status.sh` | I1 | Reports whether it's up and loopback-only, via `lsof` (not a network call — see Troubleshooting). |
| `push-fixture.sh [V1..V6] [--watch]` | I2 | Pushes `convex-tutorial`'s `proofVehicle` functions, sets `PROOF_VEHICLE_FIXTURE=1`, optionally loads one corpus vector, optionally starts `convex dev` in watch mode. |
| `build-skip-wasm.sh [--force]` | I3 | Builds `@skipruntime/wasm` via Apple's `container` CLI (Docker substitute). Idempotent — skips if `dist/` already exists. |
| `smoke-skip-wasm.mjs` | I3b | Starts the built runtime, applies one update, confirms it's observed, shuts down. |
| `smoke-loopback-bind.mjs` | I4 | Confirms a `127.0.0.1` bind succeeds under this session's sandbox (what the parent plan's `reference/service.ts` needs). |
| `e2e-smoke.mjs` | I5 | One combined check: Convex read + Skip runtime alive, same process. No correctness comparison. |
| `status.sh` | — | Runs all the read-only checks above and prints a combined report. |
| `up.sh [V1..V6]` | — | Runs I1 → I5 in order, stopping at the first failure. |

All scripts source `lib.sh` for shared paths/helpers and are safe to
run repeatedly (each command documents its idempotency above).

## Configuration

Everything defaults to this machine's sibling-checkout layout:

| Variable | Default | Meaning |
|---|---|---|
| `SKIP_DEV_TUTORIAL_DIR` | `~/src/convex-tutorial/.worktrees/feat-skip-shared-prereqs` | `convex-tutorial` worktree with `proofVehicle/` |
| `SKIP_DEV_SKIP_DIR` | `~/src/skip/.worktrees/feat-skip-shared-prereqs` | `skip` worktree with `skipruntime-ts/` |
| `SKIP_DEV_BACKEND_HOST` | `127.0.0.1` | Backend bind interface |
| `SKIP_DEV_BACKEND_PORT` | `3210` | Backend RPC port |
| `SKIP_DEV_BACKEND_SITE_PORT` | `3211` | Backend HTTP actions port |

Override any of them in your shell before running a script if your
checkouts live elsewhere.

Runtime state (backend log, pidfiles, watch-mode log) lives in
`.skip-local-dev/` at the repo root (gitignored — see below).

## Troubleshooting

**`EPERM` on a loopback bind or connect (Node `EPERM listen`, or the
Convex CLI looping "WebSocket error message: connect EPERM
127.0.0.1:3210" and reconnecting forever instead of failing fast).**
This is a Claude Code agent sandbox restriction, not a problem with the
backend or these scripts — confirmed in this repo by: `lsof` showing the
backend genuinely listening on `127.0.0.1:3210`, while a plain `curl` to
that same address from inside a sandboxed agent session fails instantly
with "Couldn't connect to server", and a Node `net.createServer().listen
(port, '127.0.0.1')` fails with `EPERM`. If you hit this running a
script yourself (not through an agent), it's unrelated — check nothing
else is misconfigured. If an agent hits it: either grant
`sandbox.network.allowLocalBinding: true` in Claude Code settings
(applies without a restart) and/or approve the specific command's
sandbox-bypass prompt, or run the script yourself in your own terminal
(the `!` prefix inside a Claude Code session also runs outside the
sandbox).

**`container` CLI fails with "Operation not permitted".** Same class of
sandbox restriction — `container` launches a VM, which an agent sandbox
may not be able to do. Run `build-skip-wasm.sh` in your own terminal.

**`container build` fails with `ERROR (MAP FAILED): Cannot allocate
memory`.** Documented and already fixed in this script (`SKIP_CAPACITY=
6G` at build time, `-m 12G` at run time) — see
`~/src/skip/docs/solutions/build-errors/apple-container-build-cannot-allocate-memory-skip-capacity-6g.md`
for the full root-cause writeup. If it still fails at 6G, try
`--build-arg SKIP_CAPACITY=12G` (edit the script or export and re-run).

**Convex CLI hangs with no output at all.** It's very likely reachable
network output being buffered by a pipe (e.g. `| tail`) that only
flushes at EOF, not an actual hang — redirect to a file and `tail -f`
it, or drop the pipe, before concluding something is stuck.

## Scope

These scripts orchestrate existing tooling; they change no code in
`local_backend`, `skip`, or `convex-tutorial`'s `proofVehicle` functions
or corpus. Loopback only, dev-only credentials — see the parent plan's
Scope Boundaries for the full constraints these scripts operate under.

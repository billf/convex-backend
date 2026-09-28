---
title: Claude Code agent sandbox blocks loopback bind/connect and the `container` CLI
date: 2026-09-28
category: build-errors
module: scripts/skip-local-dev
problem_type: environment_restriction
component: infrastructure
symptoms:
  - "curl to 127.0.0.1:<port> fails instantly: 'Couldn't connect to server' (exit 7), even though lsof confirms the port is genuinely listening"
  - "Node `net.createServer().listen(port, '127.0.0.1')` throws `EPERM: operation not permitted`"
  - "Convex CLI (`npx convex ...`) against a local backend prints repeating 'WebSocket error message: connect EPERM 127.0.0.1:3210 - Local (0.0.0.0:0)' and never exits, instead of failing fast"
  - "`container build` / `container run` (Apple's container CLI) fails with 'Operation not permitted'"
resolution_type: config_change
severity: medium
tags: [claude-code, sandbox, loopback, EPERM, container, skip-local-dev]
---

# Claude Code agent sandbox blocks loopback bind/connect and the `container` CLI

## Problem

Running `scripts/skip-local-dev/*` (see its README) from inside a
Claude Code agent's sandboxed Bash tool fails at the network-touching
steps (I2 push-fixture, I4 loopback-bind check, I5 e2e smoke) even when
every prerequisite is genuinely satisfied: `just generate-admin-key`
works, `lsof` shows the backend listening on `127.0.0.1:3210`/`:3211`,
and `@skipruntime/wasm` builds and runs correctly (confirmed: a
network-free Skip runtime smoke — `initService`, one `update`, one
`getAll`, `close` — passes cleanly under the same sandbox that blocks
the network calls).

## Symptoms

- `curl -sS http://127.0.0.1:3210/version` → `curl: (7) Failed to
  connect to 127.0.0.1 port 3210 after 0 ms: Couldn't connect to
  server` — instant refusal, not a real connection failure (the port is
  listening; verified with `lsof -nP -iTCP:3210 -sTCP:LISTEN`).
- `node -e "require('net').createServer().listen(58432, '127.0.0.1', ...)"`
  → `EPERM: operation not permitted 127.0.0.1:58432`.
- `npx convex env get ...` (or any Convex CLI command against a
  self-hosted `--url http://127.0.0.1:...`) hangs producing no output;
  redirecting to a file instead of piping through `tail` reveals it is
  actually looping forever: `WebSocket error message: connect EPERM
  127.0.0.1:3210 - Local (0.0.0.0:0)` / `WebSocket closed with code
  1006` / `Attempting reconnect in <n>ms`, repeating with backoff
  instead of surfacing the EPERM as a terminal error.
- `container images ls`, `container build`, `container run` all fail
  with a bare `Error: The operation couldn't be completed. Operation
  not permitted` — the `container` CLI launches a VM, which the sandbox
  also restricts.

## What Didn't Work

- Passing `allowed_domains` on the Bash tool call (e.g.
  `["version.convex.dev", "api.convex.dev"]`) — doesn't help, because
  the failure isn't a filtered *external* domain, it's the sandbox's
  general loopback bind/connect policy. The Convex CLI's own outbound
  version-check call to `version.convex.dev` was a red herring found
  while investigating; the actual hang was 100% the loopback
  WebSocket reconnect loop, confirmed by redirecting output to a file
  instead of a pipe (a plain `| tail -N` buffers all output until the
  child process's stdout closes, so a still-running, still-looping
  background command shows *zero* interim output through a pipe — don't
  mistake that for "hasn't started yet").
- `dangerouslyDisableSandbox: true` on the specific commands — the auto
  mode classifier explicitly denies this ("Reason: [Safety Bypass
  Flag]") for loopback-network and `container` commands; do not keep
  retrying it once denied (see Claude Code's own Bash-tool guidance on
  this).

## Solution

There is no in-session workaround for an agent under this sandbox
configuration. Two real options:

1. **Grant the specific setting.** `sandbox.network.allowLocalBinding:
   true` in Claude Code settings (applies without a restart) is
   documented to fix loopback *bind* EPERMs; it may also cover the
   *connect* case seen here (not yet independently confirmed against
   the connect-side failure — record the outcome here if you verify
   it). This does not help `container`, which needs a broader
   sandbox/VM exception the user grants per-command.
2. **Run it yourself.** Any of `scripts/skip-local-dev/*.sh`, or the
   `!<command>` prefix inside a Claude Code session (which runs outside
   the sandbox), works fine — this is a sandbox restriction on the
   *agent's* Bash tool, not a problem with the backend, the scripts, or
   this repo's dev workflow.

What the sandbox does **not** block, and is safe for an agent to use
for read-only verification without hitting this wall: `lsof -nP
-iTCP:<port> -sTCP:LISTEN` to confirm something is listening, and any
in-process computation with no socket at all (e.g. the Skip WASM
runtime smoke test, which starts a real `@skipruntime/wasm` instance,
applies an update, and reads it back — no network, no bind, fully
verifiable under this same sandbox).

## Why This Works

The sandbox's Bash tool applies a network policy per command; loopback
traffic (both binding a listener and connecting out to one) is outside
that policy's default allowlist unless the user has configured
`sandbox.network.allowLocalBinding` (or the equivalent), and process
types that need broader OS privileges (a `container`-launched VM) are
restricted independent of that setting. The auto-mode classifier
enforces this at the tool-call level and refuses a blanket
`dangerouslyDisableSandbox` escape hatch for it, by design — see the
harness's own Bash-tool sandbox guidance: retry once with the exact
missing host in `allowed_domains` if named, otherwise stop and report
to the user rather than repeatedly attempting to route around the
restriction through another tool, encoding, or later turn.

## Prevention

- When building or debugging `scripts/skip-local-dev/*` (or anything
  else that binds/connects to a local Convex backend) from inside an
  agent session, expect the network-touching steps to need the user's
  hands, and design verification to lean on `lsof`-based and
  network-free checks wherever the underlying claim allows it (see
  `backend-status.sh`'s `lsof`-only readiness check, and
  `smoke-skip-wasm.mjs`'s in-process-only runtime smoke, for the
  pattern).
- Don't diagnose a "hung" CLI command through a pipe (`| tail`, `| grep`,
  etc.) without first redirecting to a file and checking that file
  directly — a pipe hides all output from a still-running child until
  it exits, which looks identical to a genuine hang.

## Related Issues

- `scripts/skip-local-dev/README.md`'s Troubleshooting section (mirrors
  this entry, shorter).
- `docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md`
  I4 — exists specifically to catch this class of restriction before
  the parent plan's U11 hits it as a generic EPERM mid-unit.

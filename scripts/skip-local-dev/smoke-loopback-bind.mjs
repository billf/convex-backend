#!/usr/bin/env node
// I4: confirm this environment's sandbox lets a process bind a
// loopback-only listener the way U11's reference/service.ts will need
// to. Also confirms a non-loopback bind (0.0.0.0) is refused, matching
// every parent-plan unit's loopback-only constraint.
//
// Exit 0: loopback bind works and non-loopback bind was refused (or at
//         least did not silently succeed as loopback-equivalent).
// Exit 1: loopback bind failed -- record this as a real finding, do not
//         retry with the sandbox disabled and call that "passing" (the
//         parent plan and this plan both treat a bypass as not
//         satisfying the requirement).
//
// docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I4

import net from "node:net";

function tryBind(host) {
  return new Promise((resolve) => {
    const srv = net.createServer();
    srv.once("error", (err) => resolve({ ok: false, code: err.code, message: err.message }));
    srv.listen(0, host, () => {
      const { port } = srv.address();
      srv.close(() => resolve({ ok: true, port }));
    });
  });
}

const loopback = await tryBind("127.0.0.1");
console.log(
  loopback.ok
    ? `[smoke-loopback-bind] 127.0.0.1 bind: OK (ephemeral port ${loopback.port})`
    : `[smoke-loopback-bind] 127.0.0.1 bind: FAILED (${loopback.code}: ${loopback.message})`,
);

const wildcard = await tryBind("0.0.0.0");
console.log(
  wildcard.ok
    ? `[smoke-loopback-bind] 0.0.0.0 bind: succeeded too (port ${wildcard.port}) -- expected under` +
        " a sandbox with no non-loopback restriction; only loopback-only service binds matter here."
    : `[smoke-loopback-bind] 0.0.0.0 bind: refused (${wildcard.code}) -- consistent with a` +
        " loopback-only sandbox policy.",
);

if (!loopback.ok) {
  console.error(
    "[smoke-loopback-bind] FAIL: loopback bind did not succeed under this session's default" +
      " sandbox. Do not treat running outside the sandbox (or with it disabled) as satisfying" +
      " I4 -- if EPERM, check `sandbox.network.allowLocalBinding: true` in Claude Code settings" +
      " (applies without a restart), or run this script yourself outside the agent sandbox and" +
      " record which setting made it work.",
  );
  process.exit(1);
}

console.log("[smoke-loopback-bind] OK");
process.exit(0);

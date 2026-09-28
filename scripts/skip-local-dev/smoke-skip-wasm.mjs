#!/usr/bin/env node
// I3b: confirm the built @skipruntime/wasm runtime actually runs --
// start it, register one resource, write one value, observe one update,
// shut down cleanly. Deliberately independent of Q's reference service
// (that correctness claim stays the parent plan's U11/U15); this only
// proves the runtime builds and runs.
//
// API shapes here match skipruntime-ts/core/src/api.ts's SkipService and
// examples/convex_reactive/skip/service.ts's usage (checked directly
// against that source, not guessed): `inputs` maps names to
// `InputDefinition`s of initial entries; `resources` maps names to
// `Resource` *classes* (not instances); `ServiceInstance.getAll(name,
// params)` instantiates-reads-closes a resource in one call;
// `ServiceInstance.update(collectionName, entries)` is the write path
// (docs/plans/2026-09-11-1159-...-shared-prerequisites-plan.md KTD3
// calls this "ServiceInstance.update").
//
// Usage: node scripts/skip-local-dev/smoke-skip-wasm.mjs
// Requires SKIP_DEV_SKIP_DIR (or the default sibling-checkout path) to
// have a built skipruntime-ts/wasm/dist.
//
// docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I3

import { homedir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const skipDir =
  process.env.SKIP_DEV_SKIP_DIR ??
  path.join(homedir(), "src/skip/.worktrees/feat-skip-shared-prereqs");

const wasmEntry = path.join(skipDir, "skipruntime-ts/wasm/dist/src/node.js");
const coreEntry = path.join(skipDir, "skipruntime-ts/core/dist/src/index.js");

let initService, InputDefinition;
try {
  ({ initService } = await import(pathToFileURL(wasmEntry).href));
  ({ InputDefinition } = await import(pathToFileURL(coreEntry).href));
} catch (err) {
  console.error(
    `[smoke-skip-wasm] could not import runtime modules under ${skipDir}: ${err.message}\n` +
      "Run build-skip-wasm.sh first, or set SKIP_DEV_SKIP_DIR to your skip checkout.",
  );
  process.exit(1);
}

/** A Resource *class*: instantiate() just passes the input collection through. */
class EchoResource {
  instantiate(collections) {
    return collections.input;
  }
}

const service = {
  inputs: { input: new InputDefinition([["k", ["v0"]]]) },
  resources: { echo: EchoResource },
  createGraph(inputCollections) {
    return { input: inputCollections.input };
  },
};

const instance = await initService(service);
let ok = false;
try {
  const before = await instance.getAll("echo", {});
  await instance.update("input", [["k", ["v1"]]]);
  const after = await instance.getAll("echo", {});
  ok = JSON.stringify(before) !== JSON.stringify(after);
  if (!ok) {
    console.error(
      `[smoke-skip-wasm] no observable change: before=${JSON.stringify(before)} after=${JSON.stringify(after)}`,
    );
  }
} finally {
  await instance.close();
}

if (ok) {
  console.log("[smoke-skip-wasm] OK: runtime started, applied one update, observed the change, closed cleanly.");
  process.exit(0);
} else {
  console.error("[smoke-skip-wasm] FAIL: see output above.");
  process.exit(1);
}

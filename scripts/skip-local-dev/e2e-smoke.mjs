#!/usr/bin/env node
// I5: one check that all three pieces (backend, fixture, Skip runtime)
// are simultaneously reachable. No correctness comparison -- that's the
// parent plan's U11/U15 job.
//
// Requires: backend-up.sh has run, push-fixture.sh has run at least
// once, and build-skip-wasm.sh has produced a dist.
//
// Can be run from any directory; it resolves the `convex` package from
// SKIP_DEV_TUTORIAL_DIR's own node_modules explicitly (see below).
//
// docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I5

import { homedir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createRequire } from "node:module";

const backendUrl = process.env.SKIP_DEV_BACKEND_URL ?? "http://127.0.0.1:3210";
const skipDir =
  process.env.SKIP_DEV_SKIP_DIR ??
  path.join(homedir(), "src/skip/.worktrees/feat-skip-shared-prereqs");
const tutorialDir =
  process.env.SKIP_DEV_TUTORIAL_DIR ??
  path.join(homedir(), "src/convex-tutorial/.worktrees/feat-skip-shared-prereqs");

let failures = 0;

// 1. Convex read, through the tutorial's allSelectedRows query.
// Resolved from tutorialDir's own node_modules (not a bare specifier --
// this script's own location has no `convex` dependency) via createRequire,
// since running `node <this file>` from another directory doesn't change
// ESM's own-file-relative module resolution.
try {
  // These resolve to convex's CJS build, whose default export carries the
  // named exports (Node's CJS/ESM interop can't statically see them
  // otherwise -- confirmed by inspecting Object.keys() of each import).
  const tutorialRequire = createRequire(path.join(tutorialDir, "package.json"));
  const browserMod = await import(pathToFileURL(tutorialRequire.resolve("convex/browser")).href);
  const serverMod = await import(pathToFileURL(tutorialRequire.resolve("convex/server")).href);
  const { ConvexHttpClient } = browserMod.default ?? browserMod;
  const { makeFunctionReference } = serverMod.default ?? serverMod;
  const client = new ConvexHttpClient(backendUrl);
  const rows = await client.query(
    makeFunctionReference("proofVehicle/tables:allSelectedRows"),
    {},
  );
  console.log(`[e2e-smoke] Convex read OK: allSelectedRows returned ${rows.length} row(s).`);
} catch (err) {
  failures++;
  console.error(`[e2e-smoke] Convex read FAILED: ${err.message}`);
}

// 2. Skip runtime alive: start initService, do nothing else, shut down.
// API shapes match skipruntime-ts/core/src/api.ts -- see smoke-skip-wasm.mjs's
// header comment for how these were verified against source.
try {
  const wasmEntry = path.join(skipDir, "skipruntime-ts/wasm/dist/src/node.js");
  const coreEntry = path.join(skipDir, "skipruntime-ts/core/dist/src/index.js");
  const { initService } = await import(pathToFileURL(wasmEntry).href);
  const { InputDefinition } = await import(pathToFileURL(coreEntry).href);
  class PassThrough {
    instantiate(collections) {
      return collections.input;
    }
  }
  const instance = await initService({
    inputs: { input: new InputDefinition([]) },
    resources: { echo: PassThrough },
    createGraph(inputCollections) {
      return { input: inputCollections.input };
    },
  });
  await instance.close();
  console.log("[e2e-smoke] Skip runtime OK: initService started and closed cleanly.");
} catch (err) {
  failures++;
  console.error(`[e2e-smoke] Skip runtime FAILED: ${err.message}`);
}

if (failures > 0) {
  console.error(`[e2e-smoke] FAIL: ${failures} check(s) failed.`);
  process.exit(1);
}
console.log("[e2e-smoke] OK: backend and Skip runtime both reachable in the same process run.");
process.exit(0);

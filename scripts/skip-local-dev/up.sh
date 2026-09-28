#!/usr/bin/env bash
# Run the full I1-I5 sequence in order: backend up, fixture pushed
# (+ watch mode), Skip WASM built, sandbox loopback-bind checked, and
# the combined reachability smoke. Stops at the first failure so the
# failing unit is unambiguous.
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md
# (Definition of Done)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

skip_dev_log "=== I1: backend up ==="
./backend-up.sh

skip_dev_log "=== I2: push fixture ==="
./push-fixture.sh --watch "$@"

skip_dev_log "=== I3: build Skip WASM runtime ==="
./build-skip-wasm.sh

skip_dev_log "=== I3b: Skip runtime smoke ==="
node ./smoke-skip-wasm.mjs

skip_dev_log "=== I4: sandbox loopback-bind check ==="
node ./smoke-loopback-bind.mjs

skip_dev_log "=== I5: end-to-end reachability smoke ==="
node ./e2e-smoke.mjs

skip_dev_log "=== all checks passed. Deployment + Skip runtime are reachable. ==="
skip_dev_log "The parent plan's U11 (reference:snapshot) can now begin against a real deployment."

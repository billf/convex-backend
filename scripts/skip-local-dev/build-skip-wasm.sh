#!/usr/bin/env bash
# I3a: build @skipruntime/wasm.
#
# The Skiplang toolchain (LLVM 20 + matching wasm-ld + skargo) is not
# installed natively in this environment; the working path found in a
# prior session used Apple's `container` CLI as a Docker substitute to
# get a Linux build environment with the toolchain, then ran the npm
# build inside it. That path needs `container` itself to be runnable,
# which a sandboxed agent session cannot always do (see README.md's
# Troubleshooting section) -- run this script directly in your own
# terminal if it reports a `container` permission error under an agent.
#
# This script is idempotent: if dist/ already looks built, it reports
# success and exits without re-running the (slow, ~1-2 minute) build.
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I3

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

skip_dev_require_dir "${SKIP_DEV_SKIP_DIR}" "skip worktree" SKIP_DEV_SKIP_DIR

WASM_PKG_DIR="${SKIP_DEV_SKIP_DIR}/skipruntime-ts/wasm"
DIST_MARKER="${WASM_PKG_DIR}/dist/src"

if [ "${1:-}" != "--force" ] && [ -d "${DIST_MARKER}" ] && [ -n "$(ls -A "${DIST_MARKER}" 2>/dev/null)" ]; then
  skip_dev_log "dist already present at ${DIST_MARKER} -- skipping rebuild (use --force to rebuild)."
  exit 0
fi

command -v container >/dev/null 2>&1 || skip_dev_die \
  "Apple's 'container' CLI is not on PATH. Install it, or build natively per" \
  "${SKIP_DEV_SKIP_DIR}/INSTALL.md (LLVM 20 + matching wasm-ld + skargo)."

# Known Apple-container-VM failure mode, documented and fixed in
# ~/src/skip/docs/solutions/build-errors/apple-container-build-cannot-allocate-memory-skip-capacity-6g.md:
# the default Dockerfile build (empty SKIP_CAPACITY -> the Skip runtime's
# own 16 GB mmap reservation) exceeds the Apple container builder VM's
# virtual-memory ceiling and fails bootstrap with "ERROR (MAP FAILED):
# Cannot allocate memory". Fix: --build-arg SKIP_CAPACITY=6G (CI's
# constrained-host value; escalate to 12G if 6G still fails) at build
# time, and -m 12G at run time (the run container hits the same failure
# under default run memory).
image_tag="skiplabs/skip:latest"

skip_dev_log "one-time builder prereqs: kernel + builder VM sizing..."
container system kernel set --recommended 2>&1 | sed 's/^/  /' >&2 || true
container builder start --cpus 8 --memory 16G 2>&1 | sed 's/^/  /' >&2 || true

skip_dev_log "building the toolchain image from ${SKIP_DEV_SKIP_DIR}/Dockerfile (target: skip, SKIP_CAPACITY=6G)..."
( cd "${SKIP_DEV_SKIP_DIR}" && container build --platform linux/arm64 --progress plain \
    -f Dockerfile --build-arg SKIP_CAPACITY=6G -t "${image_tag}" --target skip . ) \
  || skip_dev_die "container build failed even with SKIP_CAPACITY=6G -- try --build-arg SKIP_CAPACITY=12G," \
    "or fall back to the native path in ${SKIP_DEV_SKIP_DIR}/INSTALL.md."

skip_dev_log "running the npm build inside the toolchain container (run memory -m 12G)..."
container run --rm -m 12G \
  -v "${SKIP_DEV_SKIP_DIR}:/build" \
  -w /build \
  "${image_tag}" \
  bash -c '
    set -eu
    echo "=== npm install --ignore-scripts ==="
    npm install --ignore-scripts
    echo "=== build @skipruntime/core ==="
    npm run build -w @skipruntime/core
    echo "=== build @skipruntime/wasm ==="
    npm run build -w @skipruntime/wasm
  ' || skip_dev_die "build failed inside the container -- see output above."

if [ -d "${DIST_MARKER}" ] && [ -n "$(ls -A "${DIST_MARKER}" 2>/dev/null)" ]; then
  skip_dev_log "build succeeded: ${DIST_MARKER}"
else
  skip_dev_die "container build reported success but ${DIST_MARKER} is still empty."
fi

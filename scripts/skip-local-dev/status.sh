#!/usr/bin/env bash
# Report status of every piece this workflow depends on, without
# starting or changing anything. Safe to run at any time.
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

echo "== backend (I1) =="
./backend-status.sh
backend_status=$?

echo
echo "== fixture worktree (I2) =="
if [ -d "${SKIP_DEV_TUTORIAL_DIR}" ]; then
  skip_dev_log "worktree: ${SKIP_DEV_TUTORIAL_DIR}"
  if [ -f "${SKIP_DEV_TUTORIAL_DIR}/.env.local" ]; then
    skip_dev_log ".env.local present:"
    sed 's/^/  /' "${SKIP_DEV_TUTORIAL_DIR}/.env.local" >&2
  else
    skip_dev_log ".env.local not present -- push-fixture.sh has not run yet."
  fi
else
  skip_dev_log "worktree not found at ${SKIP_DEV_TUTORIAL_DIR} (set SKIP_DEV_TUTORIAL_DIR)."
fi
if [ -f "${SKIP_DEV_CONVEX_WATCH_PIDFILE}" ]; then
  wpid="$(cat "${SKIP_DEV_CONVEX_WATCH_PIDFILE}")"
  if kill -0 "${wpid}" 2>/dev/null; then
    skip_dev_log "watch-mode 'convex dev': running (pid ${wpid})"
  else
    skip_dev_log "watch-mode 'convex dev': pidfile stale (pid ${wpid} not running)"
  fi
else
  skip_dev_log "watch-mode 'convex dev': not started (push-fixture.sh --watch starts it)"
fi

echo
echo "== Skip WASM runtime (I3) =="
dist_marker="${SKIP_DEV_SKIP_DIR}/skipruntime-ts/wasm/dist/src"
if [ -d "${dist_marker}" ] && [ -n "$(ls -A "${dist_marker}" 2>/dev/null)" ]; then
  skip_dev_log "built: ${dist_marker}"
else
  skip_dev_log "not built -- run build-skip-wasm.sh (needs SKIP_DEV_SKIP_DIR=${SKIP_DEV_SKIP_DIR})."
fi

echo
if [ "${backend_status}" -eq 0 ]; then
  skip_dev_log "backend looks healthy. Run 'up.sh' for the full sequence, or 'e2e-smoke.mjs' for" \
    "the combined reachability check (I5)."
else
  skip_dev_log "backend is not healthy -- run backend-up.sh first."
fi

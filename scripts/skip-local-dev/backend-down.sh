#!/usr/bin/env bash
# Stop the local backend started by backend-up.sh. Also supports
# `--reset`, which additionally clears local storage/db (I1b's restart
# cycle), matching `just reset-local-backend`.
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I1

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

if [ -f "${SKIP_DEV_BACKEND_PIDFILE}" ]; then
  pid="$(cat "${SKIP_DEV_BACKEND_PIDFILE}")"
  if kill -0 "${pid}" 2>/dev/null; then
    skip_dev_log "stopping backend (pid ${pid})..."
    kill "${pid}" 2>/dev/null
    for _ in $(seq 1 20); do
      kill -0 "${pid}" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "${pid}" 2>/dev/null || true
  fi
  rm -f "${SKIP_DEV_BACKEND_PIDFILE}"
else
  skip_dev_log "no pidfile at ${SKIP_DEV_BACKEND_PIDFILE}; if a backend from another session is" \
    "still running (e.g. started by hand, or in a prior shell), stop it yourself first."
fi

if skip_dev_port_listening "${SKIP_DEV_BACKEND_HOST}" "${SKIP_DEV_BACKEND_PORT}"; then
  skip_dev_log "warning: something is still listening on ${SKIP_DEV_BACKEND_URL} after stop."
fi

if [ "${1:-}" = "--reset" ]; then
  skip_dev_log "resetting local backend storage (just reset-local-backend)..."
  ( cd "${SKIP_DEV_CONVEX_BACKEND_DIR}" && just reset-local-backend )
  skip_dev_log "storage cleared. Next backend-up.sh starts a fresh deployment."
fi

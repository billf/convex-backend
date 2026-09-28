#!/usr/bin/env bash
# I1: start the Convex local backend, loopback-only, as a long-lived
# background process. Idempotent -- if something is already listening on
# the target port, this reports success and exits rather than starting a
# second instance.
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I1

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

if skip_dev_port_listening "${SKIP_DEV_BACKEND_HOST}" "${SKIP_DEV_BACKEND_PORT}"; then
  skip_dev_log "backend already listening on ${SKIP_DEV_BACKEND_URL} -- nothing to do."
  skip_dev_log "(use backend-down.sh first if you want to restart it cleanly)"
  exit 0
fi

skip_dev_log "starting local backend on ${SKIP_DEV_BACKEND_HOST}:${SKIP_DEV_BACKEND_PORT} (site ${SKIP_DEV_BACKEND_SITE_PORT})"
skip_dev_log "log: ${SKIP_DEV_BACKEND_LOG}"

cd "${SKIP_DEV_CONVEX_BACKEND_DIR}" || skip_dev_die "cannot cd to ${SKIP_DEV_CONVEX_BACKEND_DIR}"
nohup just run-local-backend --interface "${SKIP_DEV_BACKEND_HOST}" \
  > "${SKIP_DEV_BACKEND_LOG}" 2>&1 &
backend_pid=$!
echo "${backend_pid}" > "${SKIP_DEV_BACKEND_PIDFILE}"

skip_dev_log "waiting for ${SKIP_DEV_BACKEND_URL} to come up (pid ${backend_pid})..."
for _ in $(seq 1 60); do
  if skip_dev_port_listening "${SKIP_DEV_BACKEND_HOST}" "${SKIP_DEV_BACKEND_PORT}"; then
    skip_dev_log "backend is up."
    exit 0
  fi
  sleep 1
done

skip_dev_die "backend did not start listening within 60s -- see ${SKIP_DEV_BACKEND_LOG}"

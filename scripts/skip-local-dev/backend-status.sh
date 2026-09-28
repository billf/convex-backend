#!/usr/bin/env bash
# Report whether the local backend is up, loopback-only, and print the
# dev admin key -- using lsof (process/fd inspection) rather than a
# network connect, so this works even from inside a sandbox that blocks
# loopback network syscalls (see README.md's Troubleshooting section).
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I1

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

status=0

for port in "${SKIP_DEV_BACKEND_PORT}" "${SKIP_DEV_BACKEND_SITE_PORT}"; do
  line="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null)"
  if [ -z "${line}" ]; then
    skip_dev_log "port ${port}: not listening"
    status=1
    continue
  fi
  if echo "${line}" | grep -qE "(\*|0\.0\.0\.0):${port}"; then
    skip_dev_log "port ${port}: listening on ALL interfaces (not loopback-only!)"
    status=1
  elif echo "${line}" | grep -q "127.0.0.1:${port}"; then
    skip_dev_log "port ${port}: listening on 127.0.0.1 only (OK)"
  else
    skip_dev_log "port ${port}: listening on an unexpected interface -- ${line}"
    status=1
  fi
done

if [ -f "${SKIP_DEV_BACKEND_PIDFILE}" ]; then
  pid="$(cat "${SKIP_DEV_BACKEND_PIDFILE}")"
  if kill -0 "${pid}" 2>/dev/null; then
    skip_dev_log "backend-up.sh-managed process: pid ${pid}, running"
  else
    skip_dev_log "backend-up.sh-managed pidfile is stale (pid ${pid} not running)"
  fi
else
  skip_dev_log "no backend-up.sh pidfile -- backend, if up, was started some other way"
fi

if [ "${status}" -eq 0 ]; then
  key="$(skip_dev_require_admin_key 2>/dev/null || true)"
  skip_dev_log "admin key: ${key:-<unavailable>}"
  skip_dev_log "url: ${SKIP_DEV_BACKEND_URL}"
fi

exit "${status}"

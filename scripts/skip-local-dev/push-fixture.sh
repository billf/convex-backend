#!/usr/bin/env bash
# I2: push convex-tutorial's proofVehicle functions to the running local
# backend, set PROOF_VEHICLE_FIXTURE=1, and (optionally) load one corpus
# vector via the loader CLI.
#
# Usage:
#   push-fixture.sh              # push functions + set env flag only
#   push-fixture.sh V1           # also load corpus vector V1 (or V2..V6)
#   push-fixture.sh --watch      # push once, then leave `convex dev` running
#                                 # in watch mode (I4a's second long-lived
#                                 # process), logging to
#                                 # $SKIP_DEV_CONVEX_WATCH_LOG
#
# docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md I2

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./lib.sh

skip_dev_require_dir "${SKIP_DEV_TUTORIAL_DIR}" "convex-tutorial worktree" SKIP_DEV_TUTORIAL_DIR

if ! skip_dev_port_listening "${SKIP_DEV_BACKEND_HOST}" "${SKIP_DEV_BACKEND_PORT}"; then
  skip_dev_die "backend is not listening on ${SKIP_DEV_BACKEND_URL} -- run backend-up.sh first."
fi

ADMIN_KEY="$(skip_dev_require_admin_key)" || exit 1
[ -n "${ADMIN_KEY}" ] || skip_dev_die "generate-admin-key returned an empty key."

watch=0
vector=""
for arg in "$@"; do
  case "${arg}" in
    --watch) watch=1 ;;
    V1|V2|V3|V4|V5|V6) vector="${arg}" ;;
    *) skip_dev_die "unrecognized argument: ${arg} (expected --watch and/or one of V1..V6)" ;;
  esac
done

cd "${SKIP_DEV_TUTORIAL_DIR}" || skip_dev_die "cannot cd to ${SKIP_DEV_TUTORIAL_DIR}"

skip_dev_log "pushing proofVehicle functions to ${SKIP_DEV_BACKEND_URL} (npx convex dev --once)..."
npx convex dev --once --admin-key "${ADMIN_KEY}" --url "${SKIP_DEV_BACKEND_URL}" \
  || skip_dev_die "npx convex dev --once failed"

if [ ! -f .env.local ]; then
  skip_dev_die ".env.local was not written by the push -- something is wrong upstream."
fi
skip_dev_log ".env.local:"
sed 's/^/  /' .env.local >&2

skip_dev_log "setting PROOF_VEHICLE_FIXTURE=1..."
npx convex env set PROOF_VEHICLE_FIXTURE 1 --admin-key "${ADMIN_KEY}" --url "${SKIP_DEV_BACKEND_URL}" \
  || skip_dev_die "npx convex env set failed"

readback="$(npx convex env get PROOF_VEHICLE_FIXTURE --admin-key "${ADMIN_KEY}" --url "${SKIP_DEV_BACKEND_URL}")"
[ "${readback}" = "1" ] || skip_dev_die "PROOF_VEHICLE_FIXTURE read back as '${readback}', expected 1"
skip_dev_log "PROOF_VEHICLE_FIXTURE confirmed set."

if [ -n "${vector}" ]; then
  skip_dev_log "loading corpus vector ${vector} via the loader CLI..."
  CONVEX_URL="${SKIP_DEV_BACKEND_URL}" PROOF_VEHICLE_ADMIN_KEY="${ADMIN_KEY}" \
    npx tsx scripts/proof-vehicle-load.ts "${vector}" \
    || skip_dev_die "loader CLI failed for vector ${vector}"
fi

if [ "${watch}" -eq 1 ]; then
  skip_dev_log "starting 'npx convex dev' in watch mode (log: ${SKIP_DEV_CONVEX_WATCH_LOG})..."
  nohup npx convex dev --admin-key "${ADMIN_KEY}" --url "${SKIP_DEV_BACKEND_URL}" \
    > "${SKIP_DEV_CONVEX_WATCH_LOG}" 2>&1 &
  echo $! > "${SKIP_DEV_CONVEX_WATCH_PIDFILE}"
  skip_dev_log "watch-mode convex dev started, pid $(cat "${SKIP_DEV_CONVEX_WATCH_PIDFILE}")."
  skip_dev_log "stop it with: kill \$(cat ${SKIP_DEV_CONVEX_WATCH_PIDFILE})"
fi

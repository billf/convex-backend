#!/usr/bin/env bash
# Shared paths, defaults, and helpers for scripts/skip-local-dev/*.sh.
#
# Source this, don't execute it: `. "$(dirname "$0")/lib.sh"`.
#
# Background: docs/plans/2026-09-26-1245-chore-skip-local-convex-dev-infra-plan.md

set -uo pipefail
# shellcheck disable=SC2034  # vars here are used by every script that sources this file

# --- Repository roots -------------------------------------------------
# This repo (convex-backend) is wherever this file lives, two levels up.
SKIP_DEV_CONVEX_BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The other two repos this workflow spans are sibling checkouts on this
# machine, each with a worktree checked out to feat/skip-shared-prereqs.
# Override any of these if your layout differs.
: "${SKIP_DEV_TUTORIAL_DIR:=$HOME/src/convex-tutorial/.worktrees/feat-skip-shared-prereqs}"
: "${SKIP_DEV_SKIP_DIR:=$HOME/src/skip/.worktrees/feat-skip-shared-prereqs}"

# --- Backend connection ------------------------------------------------
: "${SKIP_DEV_BACKEND_HOST:=127.0.0.1}"
: "${SKIP_DEV_BACKEND_PORT:=3210}"
: "${SKIP_DEV_BACKEND_SITE_PORT:=3211}"
SKIP_DEV_BACKEND_URL="http://${SKIP_DEV_BACKEND_HOST}:${SKIP_DEV_BACKEND_PORT}"

# --- Runtime state (logs, pidfiles) ------------------------------------
SKIP_DEV_STATE_DIR="${SKIP_DEV_CONVEX_BACKEND_DIR}/.skip-local-dev"
SKIP_DEV_BACKEND_LOG="${SKIP_DEV_STATE_DIR}/backend.log"
SKIP_DEV_BACKEND_PIDFILE="${SKIP_DEV_STATE_DIR}/backend.pid"
SKIP_DEV_CONVEX_WATCH_LOG="${SKIP_DEV_STATE_DIR}/convex-dev-watch.log"
SKIP_DEV_CONVEX_WATCH_PIDFILE="${SKIP_DEV_STATE_DIR}/convex-dev-watch.pid"

mkdir -p "${SKIP_DEV_STATE_DIR}"

# --- Output helpers ------------------------------------------------------
skip_dev_log() { printf '[skip-local-dev] %s\n' "$*" >&2; }
skip_dev_die() {
  printf '[skip-local-dev] ERROR: %s\n' "$*" >&2
  exit 1
}

# skip_dev_require_admin_key: prints the dev admin key for this backend
# checkout (generating/reusing its persisted instance secret via the
# Justfile), or dies with a clear message.
skip_dev_require_admin_key() {
  ( cd "${SKIP_DEV_CONVEX_BACKEND_DIR}" && just generate-admin-key ) \
    || skip_dev_die "just generate-admin-key failed in ${SKIP_DEV_CONVEX_BACKEND_DIR}"
}

# skip_dev_port_listening HOST PORT: true (0) iff something is listening,
# via lsof rather than a network connect/bind syscall -- this check works
# even inside a network-restricted sandbox that blocks loopback traffic.
skip_dev_port_listening() {
  local host="$1" port="$2"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | grep -q "${host}:${port}"
}

# skip_dev_require_dir PATH LABEL: dies with a clear message pointing at
# the override env var if PATH doesn't exist.
skip_dev_require_dir() {
  local dir="$1" label="$2" override_var="$3"
  [ -d "${dir}" ] || skip_dev_die \
    "${label} not found at ${dir}. Set ${override_var} if your checkout lives elsewhere."
}

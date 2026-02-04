#!/usr/bin/env bash
set -euo pipefail

# Run the DeepSeek workspace pipeline forever on a 24h loop.
# - Keeps Mac awake via caffeinate (if available).
# - Avoids overlapping runs with a lockfile.
# - Optionally runs a post-run sync hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_RUNNER="$SCRIPT_DIR/Maroon-Core/tools/deepseek/run_workspace.sh"
SYNC_HOOK="$SCRIPT_DIR/Maroon-Core/tools/deepseek/post_run_sync.sh"

SLEEP_SECONDS="${MAROON_LOOP_SLEEP_SECONDS:-86400}"
LOG_FILE="${MAROON_LOOP_LOG:-$SCRIPT_DIR/deepseek_loop.log}"
LOCK_FILE="${MAROON_LOOP_LOCK:-/tmp/deepseek_run_forever.lock}"

SECOND_PASS="${MAROON_SECOND_PASS:-1}"
GIT_AUTOCOMMIT="${MAROON_GIT_AUTOCOMMIT:-0}"

if [[ ! -x "$CORE_RUNNER" ]]; then
  echo "Runner not found: $CORE_RUNNER" >&2
  exit 1
fi

run_once() {
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$now] Starting run" | tee -a "$LOG_FILE"

  if [[ "$SECOND_PASS" == "1" ]]; then
    MAROON_SECOND_PASS=1 \
    MAROON_GIT_AUTOCOMMIT="$GIT_AUTOCOMMIT" \
    "$CORE_RUNNER" >> "$LOG_FILE" 2>&1
  else
    MAROON_GIT_AUTOCOMMIT="$GIT_AUTOCOMMIT" \
    "$CORE_RUNNER" >> "$LOG_FILE" 2>&1
  fi

  local done
  done="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$done] Run complete" | tee -a "$LOG_FILE"

  if [[ -x "$SYNC_HOOK" ]]; then
    echo "[$done] Running post-run sync hook" | tee -a "$LOG_FILE"
    "$SYNC_HOOK" >> "$LOG_FILE" 2>&1 || true
  fi
}

acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      echo "Another run_forever process is active (pid=$pid). Exiting." >&2
      exit 1
    fi
  fi
  echo $$ > "$LOCK_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE" || true
}

main() {
  acquire_lock
  trap release_lock EXIT INT TERM

  while true; do
    run_once
    echo "Sleeping for $SLEEP_SECONDS seconds" | tee -a "$LOG_FILE"
    sleep "$SLEEP_SECONDS"
  done
}

if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dimsu "$0" "$@" || true
  exit 0
fi

main "$@"

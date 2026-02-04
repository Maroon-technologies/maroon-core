#!/usr/bin/env bash
set -euo pipefail

# Post-run sync hook.
# This script is a placeholder for pushing results to external systems:
# - Microsoft 365 (OneDrive/SharePoint)
# - Google Drive / Workspace
# - GitHub
#
# It is intentionally conservative: it only syncs if tools and config are present.
#
# Configure with env vars:
# - MAROON_RUNS_DIR (default: Maroon-Core/runs)
# - MAROON_SYNC_REMOTE (rclone remote name, e.g., "onedrive:" or "gdrive:")
# - MAROON_SYNC_SUBDIR (remote subdir, e.g., "Maroon/runs")
# - MAROON_GIT_PUSH (1 to push git commits)
#
# For Microsoft 365, configure rclone with OneDrive or SharePoint remote:
#   rclone config
# Then set MAROON_SYNC_REMOTE to your remote name.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$SCRIPT_DIR/Maroon-Core"
RUNS_DIR="${MAROON_RUNS_DIR:-$CORE_ROOT/runs}"
SYNC_REMOTE="${MAROON_SYNC_REMOTE:-}"
SYNC_SUBDIR="${MAROON_SYNC_SUBDIR:-Maroon/runs}"
GIT_PUSH="${MAROON_GIT_PUSH:-0}"

if [[ -n "$SYNC_REMOTE" ]]; then
  if command -v rclone >/dev/null 2>&1; then
    rclone sync "$RUNS_DIR" "${SYNC_REMOTE}${SYNC_SUBDIR}" --create-empty-src-dirs || true
  else
    echo "rclone not installed; skipping remote sync" >&2
  fi
fi

if [[ "$GIT_PUSH" == "1" ]]; then
  if git -C "$CORE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$CORE_ROOT" push || true
  fi
fi


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
# - MAROON_GCS_URI (e.g., "gs://your-bucket/maroon/runs")
# - MAROON_S3_URI (e.g., "s3://your-bucket/maroon/runs")
# - MAROON_AZURE_CONTAINER (e.g., "maroon-runs")
# - MAROON_AZURE_ACCOUNT (e.g., "yourstorageacct")
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

if [[ -n "${MAROON_GCS_URI:-}" ]]; then
  if command -v gsutil >/dev/null 2>&1; then
    gsutil -m rsync -r "$RUNS_DIR" "$MAROON_GCS_URI" || true
  else
    echo "gsutil not installed; skipping GCS sync" >&2
  fi
fi

if [[ -n "${MAROON_S3_URI:-}" ]]; then
  if command -v aws >/dev/null 2>&1; then
    aws s3 sync "$RUNS_DIR" "$MAROON_S3_URI" || true
  else
    echo "aws cli not installed; skipping S3 sync" >&2
  fi
fi

if [[ -n "${MAROON_AZURE_CONTAINER:-}" && -n "${MAROON_AZURE_ACCOUNT:-}" ]]; then
  if command -v az >/dev/null 2>&1; then
    az storage blob sync \
      --account-name "$MAROON_AZURE_ACCOUNT" \
      --container "$MAROON_AZURE_CONTAINER" \
      --source "$RUNS_DIR" || true
  else
    echo "az cli not installed; skipping Azure sync" >&2
  fi
fi

if [[ "$GIT_PUSH" == "1" ]]; then
  if git -C "$CORE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$CORE_ROOT" push || true
  fi
fi

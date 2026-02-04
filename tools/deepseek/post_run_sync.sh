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
# - MAROON_GEMINI_DM (1 to generate a Gemini \"DM\" memo if Gemini CLI is available)
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
GEMINI_DM="${MAROON_GEMINI_DM:-0}"

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

# Optional Gemini DM memo from latest run summaries (if CLI is available).
if [[ "$GEMINI_DM" == "1" ]]; then
  if command -v gemini >/dev/null 2>&1 || command -v gemini-cli >/dev/null 2>&1 || command -v google-gemini >/dev/null 2>&1; then
    GEMINI_BIN="$(command -v gemini || command -v gemini-cli || command -v google-gemini)"
    LATEST_FILE="$RUNS_DIR/LATEST"
    if [[ -f "$LATEST_FILE" ]]; then
      RUN_TS="$(cat "$LATEST_FILE" | tr -d '[:space:]')"
      RUN_DIR="$RUNS_DIR/$RUN_TS"
      SUMMARY="$RUN_DIR/corpus_summary.md"
      GAPS="$RUN_DIR/corpus_gaps.md"
      PRIORITIES="$RUN_DIR/corpus_priorities.md"
      DM_OUT="$RUN_DIR/gemini_dm.md"
      if [[ -f "$SUMMARY" ]]; then
        PROMPT="Write a concise executive DM memo (<=400 words) summarizing status, gaps, and next actions. Use Harvard-grade clarity. Do not invent facts.\\n\\nSUMMARY:\\n$(cat "$SUMMARY")"
        if [[ -f "$GAPS" ]]; then
          PROMPT+="\\n\\nGAPS:\\n$(cat "$GAPS")"
        fi
        if [[ -f "$PRIORITIES" ]]; then
          PROMPT+="\\n\\nPRIORITIES:\\n$(cat "$PRIORITIES")"
        fi
        echo "$PROMPT" | "$GEMINI_BIN" > "$DM_OUT" 2>/dev/null || true
      fi
    fi
  fi
fi

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
# - MAROON_PATTERN_SCAN (1 to generate pattern_index.md/json each cycle)
# - MAROON_CYCLE_LEDGER (1 to append a cycle ledger entry each cycle)
# - MAROON_RUN_NOTES (1 to write a run_notes.md summary each cycle)
# - MAROON_NEXT_STEP_DIRECTIVE (override the default next-step directive text)
#
# For Microsoft 365, configure rclone with OneDrive or SharePoint remote:
#   rclone config
# Then set MAROON_SYNC_REMOTE to your remote name.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  CORE_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
  CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
RUNS_DIR="${MAROON_RUNS_DIR:-$CORE_ROOT/runs}"
SYNC_REMOTE="${MAROON_SYNC_REMOTE:-}"
SYNC_SUBDIR="${MAROON_SYNC_SUBDIR:-Maroon/runs}"
GIT_PUSH="${MAROON_GIT_PUSH:-0}"
GEMINI_DM="${MAROON_GEMINI_DM:-0}"
PATTERN_SCAN="${MAROON_PATTERN_SCAN:-1}"
CYCLE_LEDGER="${MAROON_CYCLE_LEDGER:-1}"
RUN_NOTES="${MAROON_RUN_NOTES:-1}"
NEXT_STEP_DIRECTIVE="${MAROON_NEXT_STEP_DIRECTIVE:-Prepare this corpus for the 40B offline model on the desktop. That model will be the official brain. Every cycle should harden, simplify, and upgrade incomplete docs to be ready for 40B takeover.}"

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

# Pattern scan snapshot
if [[ "$PATTERN_SCAN" == "1" ]]; then
  if [[ -x "$SCRIPT_DIR/pattern_scan.sh" ]]; then
    CORE_ROOT="$CORE_ROOT" RUNS_DIR="$RUNS_DIR" "$SCRIPT_DIR/pattern_scan.sh" >/dev/null 2>&1 || true
  fi
fi

# Cycle ledger (always append a single line + snapshot per run)
if [[ "$CYCLE_LEDGER" == "1" ]]; then
  LATEST_FILE="$RUNS_DIR/LATEST"
  if [[ -f "$LATEST_FILE" ]]; then
    RUN_TS="$(cat "$LATEST_FILE" | tr -d '[:space:]')"
    RUN_DIR="$RUNS_DIR/$RUN_TS"
    INDEX_JSON="$RUN_DIR/pattern_index.json"
    LEDGER="$RUNS_DIR/cycle_ledger.md"
    SNAPSHOT="$RUN_DIR/cycle_snapshot.md"
    if [[ -f "$INDEX_JSON" ]]; then
      python3 - <<'PY'
import json, os, sys, datetime
run_dir = os.environ.get("RUN_DIR")
index_json = os.environ.get("INDEX_JSON")
ledger = os.environ.get("LEDGER")
snapshot = os.environ.get("SNAPSHOT")
run_ts = os.environ.get("RUN_TS")

data = json.load(open(index_json, "r", encoding="utf-8"))
counts = data.get("counts", {})
pat = data.get("patent_docs", {})
line = (
    f"- {datetime.datetime.now().isoformat(timespec='seconds')}"
    f" | run {run_ts}"
    f" | maroon {counts.get('maroon')}"
    f" | patent_docs {pat.get('draft_files_count')}"
    f" | portfolio {pat.get('portfolio_opportunities')}"
    f" | filed_reported {pat.get('filed_patents_user_reported')}"
)

os.makedirs(os.path.dirname(ledger), exist_ok=True)
with open(ledger, "a", encoding="utf-8") as f:
    if os.path.getsize(ledger) == 0:
        f.write("# Cycle Ledger\n\n")
    f.write(line + "\n")

with open(snapshot, "w", encoding="utf-8") as f:
    f.write("# Cycle Snapshot\n\n")
    f.write(line + "\n\n")
    f.write("## Counts\n")
    for k in sorted(counts.keys()):
        f.write(f"- {k}: {counts.get(k)}\n")
    f.write("\n## Patents\n")
    f.write(f"- draft_files_count: {pat.get('draft_files_count')}\n")
    f.write(f"- portfolio_opportunities: {pat.get('portfolio_opportunities')}\n")
    f.write(f"- extraction_report_opportunities: {pat.get('extraction_report_opportunities')}\n")
    f.write(f"- email_claimed_innovations: {pat.get('email_claimed_innovations')}\n")
    f.write(f"- filed_patents_user_reported: {pat.get('filed_patents_user_reported')}\n")
PY
    fi
  fi
fi

# Per-run notes (summary + gaps + priorities) written into the run folder.
if [[ "$RUN_NOTES" == "1" ]]; then
  LATEST_FILE="$RUNS_DIR/LATEST"
  if [[ -f "$LATEST_FILE" ]]; then
    RUN_TS="$(cat "$LATEST_FILE" | tr -d '[:space:]')"
    RUN_DIR="$RUNS_DIR/$RUN_TS"
    SUMMARY="$RUN_DIR/corpus_summary.md"
    GAPS="$RUN_DIR/corpus_gaps.md"
    PRIORITIES="$RUN_DIR/corpus_priorities.md"
    NOTES="$RUN_DIR/run_notes.md"
    if [[ -f "$SUMMARY" ]]; then
      {
        echo "# Run Notes"
        echo ""
        echo "Run: $RUN_TS"
        echo ""
        echo "## Next-Step Directive"
        echo "$NEXT_STEP_DIRECTIVE"
        echo ""
        echo "## Summary"
        cat "$SUMMARY"
        echo ""
        if [[ -f "$GAPS" ]]; then
          echo "## Gaps"
          cat "$GAPS"
          echo ""
        fi
        if [[ -f "$PRIORITIES" ]]; then
          echo "## Priorities"
          cat "$PRIORITIES"
          echo ""
        fi
      } > "$NOTES"
    fi
  fi
fi

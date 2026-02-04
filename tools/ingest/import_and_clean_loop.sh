#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/load_env.sh" ]]; then
  source "$SCRIPT_DIR/load_env.sh"
fi

SLEEP_SECONDS="${MAROON_INGEST_LOOP_SLEEP:-60}"

while true; do
  python3 "$SCRIPT_DIR/import_chatgpt_export.py" || true
  python3 "$SCRIPT_DIR/clean_ingest.py" || true
  sleep "$SLEEP_SECONDS"
done

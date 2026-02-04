#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

QUEUE_DIR="${MAROON_REQUEST_QUEUE_DIR:-$CORE_ROOT/requests/pending}"
PROCESSED_DIR="${MAROON_REQUEST_PROCESSED_DIR:-$CORE_ROOT/requests/processed}"
LOG_FILE="${MAROON_REQUEST_LOG:-$CORE_ROOT/requests/REQUEST_LOG.md}"

mkdir -p "$QUEUE_DIR" "$PROCESSED_DIR"

shopt -s nullglob
files=("$QUEUE_DIR"/*.json)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No pending requests." >&2
  exit 0
fi

for f in "${files[@]}"; do
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  base="$(basename "$f")"
  summary="$(python3 - <<'PY'
import json, sys
p=sys.argv[1]
try:
    data=json.load(open(p, 'r', encoding='utf-8'))
    rel=data.get('source_relpath')
    actions=(data.get('actions_text') or '').strip().splitlines()
    first=actions[0] if actions else ''
    print(f"{rel} | {first[:120]}")
except Exception:
    print("(unable to parse)")
PY
"$f")"
  {
    if [[ ! -f "$LOG_FILE" ]]; then
      echo "# DeepSeek Request Log"
      echo ""
    fi
    echo "- $ts | $base | $summary"
  } >> "$LOG_FILE"

  mv "$f" "$PROCESSED_DIR/$base"

done

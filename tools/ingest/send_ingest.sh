#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/load_env.sh" ]]; then
  source "$SCRIPT_DIR/load_env.sh"
fi

API_URL="${MAROON_INGEST_URL:-http://localhost:8000/ingest}"
API_KEY="${MAROON_INGEST_API_KEY:-}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <payload.json>" >&2
  exit 1
fi

PAYLOAD="$1"
if [[ ! -f "$PAYLOAD" ]]; then
  echo "Payload not found: $PAYLOAD" >&2
  exit 1
fi

AUTH_HEADER=()
if [[ -n "$API_KEY" ]]; then
  AUTH_HEADER=( -H "X-Maroon-Key: $API_KEY" )
fi

curl -sS -X POST "$API_URL" \
  -H 'Content-Type: application/json' \
  "${AUTH_HEADER[@]}" \
  --data-binary "@$PAYLOAD"

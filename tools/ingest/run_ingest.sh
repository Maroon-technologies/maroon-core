#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE_ROOT="$(cd "$CORE_ROOT/.." && pwd)"

if [[ -x "$SCRIPT_DIR/load_env.sh" ]]; then
  source "$SCRIPT_DIR/load_env.sh"
fi

export MAROON_INGEST_DIR="${MAROON_INGEST_DIR:-$WORKSPACE_ROOT/maroon_ingest}"

cd "$SCRIPT_DIR"
python3 -m uvicorn ingest_api:app --host 0.0.0.0 --port 8000

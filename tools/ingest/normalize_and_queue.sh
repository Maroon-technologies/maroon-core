#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/load_env.sh" ]]; then
  source "$SCRIPT_DIR/load_env.sh"
fi

python3 "$SCRIPT_DIR/clean_ingest.py"

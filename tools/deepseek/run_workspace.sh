#!/usr/bin/env bash
set -euo pipefail

# Run the DeepSeek pipeline against the *workspace* (parent of Maroon-Core),
# while storing git-trackable summaries under Maroon-Core/runs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
WORKSPACE_ROOT="$(cd "$CORE_ROOT/.." && pwd)"

export MAROON_ROOT="$WORKSPACE_ROOT"
export MAROON_OUTPUT_DIR="$WORKSPACE_ROOT/deepseek_outputs"
export MAROON_RUNS_DIR="$CORE_ROOT/runs"

"$SCRIPT_DIR/deepseek_maroon_cleanup.sh"

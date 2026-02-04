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

# Mark run in-progress for visibility.
IN_PROGRESS="$MAROON_RUNS_DIR/IN_PROGRESS"
mkdir -p "$MAROON_RUNS_DIR"
{
  echo "started_at=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "pid=$$"
  echo "run_host=$(hostname)"
} > "$IN_PROGRESS"
trap 'rm -f "$IN_PROGRESS"' EXIT INT TERM

# Ensure the scan is global (not accidentally restricted by a leftover MAROON_GLOB).
unset MAROON_GLOB || true
export MAROON_GLOBS="${MAROON_GLOBS:-*maroon*.md,*patent*.md,*schema*.md,*business*.md,*system*.md,*ontology*.md,*spec*.md,*truth*.md,*nanny*.md}"
export MAROON_FILED_PATENTS="${MAROON_FILED_PATENTS:-2}"

"$SCRIPT_DIR/deepseek_maroon_cleanup.sh"

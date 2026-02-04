#!/usr/bin/env bash
set -euo pipefail

# Build a maroon*.md catalog for the latest run.
# Outputs:
# - Maroon-Core/runs/<timestamp>/maroon_index.md
# - Maroon-Core/runs/<timestamp>/maroon_index.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  CORE_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
  CORE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

WORKSPACE_ROOT="$(cd "$CORE_ROOT/.." && pwd)"
RUNS_DIR="${MAROON_RUNS_DIR:-$CORE_ROOT/runs}"
LATEST_FILE="$RUNS_DIR/LATEST"

if [[ ! -f "$LATEST_FILE" ]]; then
  echo "No LATEST run found at $LATEST_FILE" >&2
  exit 1
fi

RUN_TS="$(cat "$LATEST_FILE" | tr -d '[:space:]')"
OUT_DIR="$RUNS_DIR/$RUN_TS"
mkdir -p "$OUT_DIR"

CORE_ROOT="$CORE_ROOT" RUNS_DIR="$RUNS_DIR" WORKSPACE_ROOT="$WORKSPACE_ROOT" python3 - <<'PY'
import fnmatch
import json
import os
import re
from collections import defaultdict
from datetime import datetime

core_root = os.environ.get("CORE_ROOT")
if not core_root:
    raise SystemExit("CORE_ROOT env var is required")
workspace_root = os.environ.get("WORKSPACE_ROOT") or os.path.abspath(os.path.join(core_root, ".."))

runs_dir = os.environ.get("RUNS_DIR") or os.path.join(core_root, "runs")
latest_path = os.path.join(runs_dir, "LATEST")
run_ts = open(latest_path, "r", encoding="utf-8").read().strip()
out_dir = os.path.join(runs_dir, run_ts)
os.makedirs(out_dir, exist_ok=True)

prune_dirs = {".git", "node_modules", ".venv", "venv", "dist", "build", "target", "__pycache__", ".pytest_cache", ".cache", "deepseek_outputs", "runs"}

files = []
for cur, dirs, fs in os.walk(workspace_root):
    dirs[:] = [d for d in dirs if d not in prune_dirs]
    for f in fs:
        lf = f.lower()
        if not lf.endswith('.md'):
            continue
        if not fnmatch.fnmatch(lf, '*maroon*.md'):
            continue
        path = os.path.join(cur, f)
        rel = os.path.relpath(path, workspace_root)
        files.append(rel)

files_sorted = sorted(files)

def norm(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s

# Group by normalized filename (without extension)
by_name = defaultdict(list)
for rel in files_sorted:
    base = os.path.splitext(os.path.basename(rel))[0]
    by_name[norm(base)].append(rel)

# Duplicates: groups with >1
duplicates = {k: v for k, v in by_name.items() if len(v) > 1}

summary = {
    "timestamp": datetime.now().isoformat(timespec="seconds"),
    "workspace_root": workspace_root,
    "maroon_files_count": len(files_sorted),
    "maroon_files": files_sorted,
    "duplicate_groups": duplicates,
}

json_path = os.path.join(out_dir, "maroon_index.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)

md = []
md.append("# Maroon Index")
md.append("")
md.append(f"Generated: {summary['timestamp']}")
md.append("")
md.append(f"Total maroon*.md files: {summary['maroon_files_count']}")
md.append("")
md.append("## Files")
for rel in files_sorted:
    md.append(f"- {rel}")

if duplicates:
    md.append("")
    md.append("## Potential Duplicates (by normalized name)")
    for k in sorted(duplicates.keys()):
        files = " | ".join(sorted(duplicates[k]))
        md.append(f"- {k}: {files}")

md_path = os.path.join(out_dir, "maroon_index.md")
with open(md_path, "w", encoding="utf-8") as f:
    f.write("\n".join(md) + "\n")
PY

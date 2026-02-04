#!/usr/bin/env bash
set -euo pipefail

# Pattern and patent indexer.
# Writes a snapshot under Maroon-Core/runs/<timestamp>/pattern_index.(md|json)

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

python3 - <<'PY'
import fnmatch
import json
import os
import re
from datetime import datetime

core_root = os.environ.get("CORE_ROOT")
if not core_root:
    # infer from script path
    core_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
workspace_root = os.path.abspath(os.path.join(core_root, ".."))

runs_dir = os.environ.get("RUNS_DIR")
if not runs_dir:
    runs_dir = os.path.join(core_root, "runs")
latest_path = os.path.join(runs_dir, "LATEST")
if not os.path.isfile(latest_path):
    raise SystemExit("No LATEST run found")

run_ts = open(latest_path, "r", encoding="utf-8").read().strip()
out_dir = os.path.join(runs_dir, run_ts)
os.makedirs(out_dir, exist_ok=True)

categories = {
    "maroon": ["*maroon*.md"],
    "patent": ["*patent*.md"],
    "schema": ["*schema*.md"],
    "business": ["*business*.md"],
    "system": ["*system*.md"],
    "ontology": ["*ontology*.md"],
    "spec": ["*spec*.md"],
    "truth": ["*truth*.md"],
    "nanny": ["*nanny*.md"],
}

prune_dirs = {".git", "node_modules", ".venv", "venv", "dist", "build", "target", "__pycache__", ".pytest_cache", ".cache", "deepseek_outputs", "runs"}


def scan():
    results = {k: [] for k in categories}
    for cur, dirs, files in os.walk(workspace_root):
        dirs[:] = [d for d in dirs if d not in prune_dirs]
        for f in files:
            lf = f.lower()
            if not lf.endswith(".md"):
                continue
            path = os.path.join(cur, f)
            rel = os.path.relpath(path, workspace_root)
            for cat, globs in categories.items():
                if any(fnmatch.fnmatch(lf, g) for g in globs):
                    results[cat].append(rel)
    return results


results = scan()

# Patent-specific info
patents_dir = os.path.join(core_root, "patents")
patent_files = []
if os.path.isdir(patents_dir):
    for name in sorted(os.listdir(patents_dir)):
        if re.match(r"PATENT_\d+_.*\.md$", name):
            patent_files.append(os.path.join("Maroon-Core", "patents", name))

patent_dirs = []
if os.path.isdir(patents_dir):
    for name in sorted(os.listdir(patents_dir)):
        if re.match(r"PATENT_\d+_.*", name) and os.path.isdir(os.path.join(patents_dir, name)):
            patent_dirs.append(os.path.join("Maroon-Core", "patents", name))

portfolio_path = os.path.join(patents_dir, "COMPLETE_PATENT_PORTFOLIO.md")
portfolio_count = None
if os.path.isfile(portfolio_path):
    txt = open(portfolio_path, "r", encoding="utf-8", errors="ignore").read()
    m = re.search(r"Total Patent Opportunities\s*:\s*(\d+)", txt, re.IGNORECASE)
    if m:
        portfolio_count = int(m.group(1))

extraction_path = os.path.join(patents_dir, "PATENT_EXTRACTION_REPORT.md")
extraction_count = None
if os.path.isfile(extraction_path):
    txt = open(extraction_path, "r", encoding="utf-8", errors="ignore").read()
    m = re.search(r"Total Opportunities\s*:\s*(\d+)", txt, re.IGNORECASE)
    if m:
        extraction_count = int(m.group(1))

email_path = os.path.join(patents_dir, "EMAIL_TO_SEAN_DRAFT.md")
email_claim = None
if os.path.isfile(email_path):
    txt = open(email_path, "r", encoding="utf-8", errors="ignore").read()
    m = re.search(r"(\d+)\s+patent-related innovations", txt, re.IGNORECASE)
    if m:
        email_claim = int(m.group(1))

summary = {
    "timestamp": datetime.now().isoformat(timespec="seconds"),
    "workspace_root": workspace_root,
    "counts": {k: len(v) for k, v in results.items()},
    "patent_docs": {
        "draft_files_count": len(patent_files),
        "draft_files": patent_files,
        "draft_dirs_count": len(patent_dirs),
        "draft_dirs": patent_dirs,
        "portfolio_opportunities": portfolio_count,
        "extraction_report_opportunities": extraction_count,
        "email_claimed_innovations": email_claim,
    },
}

# Write JSON
json_path = os.path.join(out_dir, "pattern_index.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(summary, f, indent=2)

# Write Markdown
md_lines = []
md_lines.append("# Pattern Index")
md_lines.append("")
md_lines.append(f"Generated: {summary['timestamp']}")
md_lines.append("")
md_lines.append("## Counts by Category")
for k, v in summary["counts"].items():
    md_lines.append(f"- {k}: {v}")

md_lines.append("")
md_lines.append("## Patent Summary")
md_lines.append(f"- Draft patent files: {summary['patent_docs']['draft_files_count']}")
md_lines.append(f"- Draft patent folders: {summary['patent_docs']['draft_dirs_count']}")
md_lines.append(f"- Portfolio opportunities (COMPLETE_PATENT_PORTFOLIO): {summary['patent_docs']['portfolio_opportunities']}")
md_lines.append(f"- Extraction report opportunities (PATENT_EXTRACTION_REPORT): {summary['patent_docs']['extraction_report_opportunities']}")
md_lines.append(f"- Email claimed innovations: {summary['patent_docs']['email_claimed_innovations']}")

if summary['patent_docs']['draft_files']:
    md_lines.append("")
    md_lines.append("### Draft Patent Files")
    for p in summary['patent_docs']['draft_files']:
        md_lines.append(f"- {p}")

md_lines.append("")
md_lines.append("## Notes")
md_lines.append("- Counts may conflict across sources; use this index to reconcile.")
md_lines.append("- Prioritize patent docs, schemas, and system specs for consolidation.")

md_path = os.path.join(out_dir, "pattern_index.md")
with open(md_path, "w", encoding="utf-8") as f:
    f.write("\n".join(md_lines) + "\n")
PY

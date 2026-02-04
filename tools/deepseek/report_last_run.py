#!/usr/bin/env python3
import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime

def find_latest_run(output_root: Path, run_ts: str | None = None) -> Path:
    if run_ts:
        run_dir = output_root / run_ts
        if run_dir.exists():
            return run_dir
        raise SystemExit(f"Run directory not found: {run_dir}")
    latest_file = output_root / "LATEST"
    if latest_file.exists():
        run_ts = latest_file.read_text(encoding="utf-8").strip()
        run_dir = output_root / run_ts
        if run_dir.exists():
            return run_dir
    # fallback: most recent dir
    candidates = [p for p in output_root.iterdir() if p.is_dir()]
    if not candidates:
        raise SystemExit("No deepseek_outputs run directories found")
    return max(candidates, key=lambda p: p.stat().st_mtime)

def last_progress_line(log_path: Path):
    if not log_path.exists():
        return None
    pat = re.compile(r"\[(\d+)/(\d+)\]")
    last = None
    for line in log_path.read_text(errors="ignore").splitlines():
        m = pat.search(line)
        if m:
            last = (int(m.group(1)), int(m.group(2)), line)
    return last

def to_relative(path: str, workspace_root: Path) -> str:
    if not path:
        return ""
    p = Path(path)
    try:
        return str(p.relative_to(workspace_root))
    except ValueError:
        return path


def categorize(path: str) -> str:
    parts = path.split("/")
    return "/".join(parts[:2]) if len(parts) >= 2 else parts[0]


def main():
    workspace_root = Path(__file__).resolve().parents[3]
    output_root = workspace_root / "deepseek_outputs"
    run_ts_arg = sys.argv[1] if len(sys.argv) > 1 else None
    run_dir = find_latest_run(output_root, run_ts_arg)

    entries = []
    for sub in sorted(run_dir.iterdir()):
        if not sub.is_dir():
            continue
        input_path_file = sub / "input_path.txt"
        input_path_raw = input_path_file.read_text(encoding="utf-8").strip() if input_path_file.exists() else ""
        input_path = to_relative(input_path_raw, workspace_root)
        entry = {
            "dir": sub.name,
            "input_path": input_path,
            "rewrite": (sub / "rewrite.md").exists(),
            "analysis": (sub / "analysis.md").exists(),
            "actions": (sub / "actions.md").exists(),
            "diff": (sub / "diff.patch").exists(),
        }
        entries.append(entry)

    total = len(entries)
    rewrite_count = sum(1 for e in entries if e["rewrite"])
    analysis_count = sum(1 for e in entries if e["analysis"])
    actions_count = sum(1 for e in entries if e["actions"])
    diff_count = sum(1 for e in entries if e["diff"])

    by_category = {}
    for e in entries:
        key = categorize(e["input_path"]) if e["input_path"] else "unknown"
        by_category[key] = by_category.get(key, 0) + 1

    log_path = workspace_root / "Maroon-Core" / "tools" / "deepseek" / "deepseek_loop.log"
    progress = last_progress_line(log_path)

    report = []
    report.append("# DeepSeek Run Report")
    report.append("")
    report.append(f"Generated: {datetime.now().isoformat(timespec='seconds')}")
    report.append(f"Run dir: {run_dir}")
    report.append("Model: deepseek-r1:8b (ollama)")
    report.append("")
    if progress:
        cur, total_expected, line = progress
        pct = round((cur / total_expected) * 100, 1) if total_expected else 0.0
        report.append(f"Last progress line: {line}")
        report.append(f"Progress at stop: {cur}/{total_expected} ({pct}%)")
        report.append("")
    report.append("## Summary")
    report.append(f"- total_entries_found: {total}")
    report.append(f"- rewrites_present: {rewrite_count}")
    report.append(f"- analysis_present: {analysis_count}")
    report.append(f"- actions_present: {actions_count}")
    report.append(f"- diffs_present: {diff_count}")
    report.append("")
    report.append("## Counts By Category")
    for k in sorted(by_category.keys()):
        report.append(f"- {k}: {by_category[k]}")
    report.append("")
    report.append("## Files")
    for e in entries:
        report.append(
            f"- {e['input_path'] or e['dir']} | rewrite: {e['rewrite']} | analysis: {e['analysis']} | actions: {e['actions']} | diff: {e['diff']}"
        )

    runs_dir = workspace_root / "Maroon-Core" / "runs"
    runs_dir.mkdir(parents=True, exist_ok=True)
    report_path = runs_dir / f"REPORT_{run_dir.name}.md"
    report_path.write_text("\n".join(report) + "\n", encoding="utf-8")

    print(str(report_path))

if __name__ == "__main__":
    main()

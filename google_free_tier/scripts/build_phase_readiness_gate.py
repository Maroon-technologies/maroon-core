#!/usr/bin/env python3
"""Build a deterministic phase-readiness gate for MAROON corpus operations."""

from __future__ import annotations

import argparse
import csv
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def date_tag() -> str:
    return datetime.now(UTC).strftime("%Y_%m_%d")


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def load_redteam_gap_counts(path: Path) -> dict[str, int]:
    counts = {"total": 0, "p0": 0, "p1": 0, "p2": 0}
    if not path.exists():
        return counts
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            counts["total"] += 1
            sev = (row.get("severity") or "").strip().upper()
            if sev == "P0":
                counts["p0"] += 1
            elif sev == "P1":
                counts["p1"] += 1
            elif sev == "P2":
                counts["p2"] += 1
    return counts


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except Exception:
        return default


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_md(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def build_args() -> argparse.Namespace:
    gft_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gft-root", default=str(gft_default))
    parser.add_argument("--min-priority-line-coverage", type=float, default=95.0)
    parser.add_argument("--min-core-line-coverage", type=float, default=10.0)
    parser.add_argument("--max-open-gaps", type=int, default=2)
    parser.add_argument("--max-critical-missing", type=int, default=0)
    parser.add_argument("--max-p0-redteam", type=int, default=0)
    return parser.parse_args()


def main() -> int:
    args = build_args()
    gft_root = Path(args.gft_root).expanduser().resolve()
    ops_dir = gft_root / "workspace" / "Maroon" / "Reports" / "Ops"

    corpus_snapshot = load_json(ops_dir / "maroon_corpus_quality_snapshot_latest.json")
    forensic_snapshot = load_json(ops_dir / "maroon_db_embedding_forensic_inspection_latest.json")
    redteam_gap_counts = load_redteam_gap_counts(ops_dir / "maroon_red_team6_gap_register_latest.csv")

    priority_line_coverage_pct = to_float(corpus_snapshot.get("priority_line_coverage_pct"))
    core_line_coverage_pct = to_float(corpus_snapshot.get("core_line_coverage_pct"))
    open_gaps_total = to_int(corpus_snapshot.get("open_gaps_total"))
    critical_missing_total = to_int(corpus_snapshot.get("critical_missing_total"))

    forensic_health_flags = forensic_snapshot.get("health_flags")
    if not isinstance(forensic_health_flags, list):
        forensic_health_flags = []

    metrics = {
        "priority_line_coverage_pct": priority_line_coverage_pct,
        "core_line_coverage_pct": core_line_coverage_pct,
        "open_gaps_total": open_gaps_total,
        "critical_missing_total": critical_missing_total,
        "redteam_total_gaps": redteam_gap_counts["total"],
        "redteam_p0_gaps": redteam_gap_counts["p0"],
        "forensic_health_flag_count": len(forensic_health_flags),
    }

    hard_blockers: list[str] = []
    warnings: list[str] = []

    if priority_line_coverage_pct < args.min_priority_line_coverage:
        hard_blockers.append(
            f"priority_line_coverage_pct {priority_line_coverage_pct:.2f} < {args.min_priority_line_coverage:.2f}"
        )
    if core_line_coverage_pct < args.min_core_line_coverage:
        hard_blockers.append(
            f"core_line_coverage_pct {core_line_coverage_pct:.2f} < {args.min_core_line_coverage:.2f}"
        )
    if open_gaps_total > args.max_open_gaps:
        hard_blockers.append(f"open_gaps_total {open_gaps_total} > {args.max_open_gaps}")
    if critical_missing_total > args.max_critical_missing:
        hard_blockers.append(
            f"critical_missing_total {critical_missing_total} > {args.max_critical_missing}"
        )
    if redteam_gap_counts["p0"] > args.max_p0_redteam:
        hard_blockers.append(f"redteam_p0_gaps {redteam_gap_counts['p0']} > {args.max_p0_redteam}")

    for flag in forensic_health_flags:
        flag_text = str(flag)
        if flag_text == "missing_latest_architecture_run":
            hard_blockers.append("missing_latest_architecture_run")
        elif flag_text in {
            "lineage_rows_zero",
            "systems_missing_pillar",
            "systems_missing_commercial_action",
            "ownership_missing_owner",
            "ownership_missing_disclosure",
            "missing_corpus_quality_overview",
            "corpus_p0_gaps_present",
        }:
            hard_blockers.append(flag_text)
        else:
            warnings.append(flag_text)

    if hard_blockers:
        recommended_stage = "cleaning_hardening"
        readiness_level = "NOT_READY"
    else:
        recommended_stage = "synthesis_parallel_cleanup"
        readiness_level = "READY"

    now = utc_now()
    payload = {
        "generated_at": now,
        "recommended_stage": recommended_stage,
        "readiness_level": readiness_level,
        "metrics": metrics,
        "hard_blockers": hard_blockers,
        "warnings": warnings,
        "forensic_health_status": str(forensic_snapshot.get("health_status") or "unknown"),
        "run_id": str(corpus_snapshot.get("run_id") or ""),
        "operator_directive": (
            "Move to synthesis and artifact expansion while keeping nightly cleanup running."
            if readiness_level == "READY"
            else "Keep focus on cleaning/hardening until blockers are closed."
        ),
    }

    stamp = date_tag()
    out_json = ops_dir / f"maroon_phase_readiness_gate_{stamp}.json"
    out_json_latest = ops_dir / "maroon_phase_readiness_gate_latest.json"
    out_md = ops_dir / f"maroon_phase_readiness_gate_{stamp}.md"
    out_md_latest = ops_dir / "maroon_phase_readiness_gate_latest.md"

    write_json(out_json, payload)
    write_json(out_json_latest, payload)

    md_lines = [
        "# MAROON Phase Readiness Gate",
        "",
        f"Generated: `{now}`",
        f"Readiness level: `{readiness_level}`",
        f"Recommended stage: `{recommended_stage}`",
        "",
        "## Metrics",
        "",
        f"- priority_line_coverage_pct: `{priority_line_coverage_pct:.2f}`",
        f"- core_line_coverage_pct: `{core_line_coverage_pct:.2f}`",
        f"- open_gaps_total: `{open_gaps_total}`",
        f"- critical_missing_total: `{critical_missing_total}`",
        f"- redteam_p0_gaps: `{redteam_gap_counts['p0']}`",
        f"- forensic_health_flag_count: `{len(forensic_health_flags)}`",
        "",
        "## Hard Blockers",
        "",
    ]

    if hard_blockers:
        for blocker in hard_blockers:
            md_lines.append(f"- {blocker}")
    else:
        md_lines.append("- none")

    md_lines.extend(["", "## Warnings", ""])
    if warnings:
        for warning in warnings:
            md_lines.append(f"- {warning}")
    else:
        md_lines.append("- none")

    md_lines.extend(["", "## Operator Directive", "", f"- {payload['operator_directive']}"])

    write_md(out_md, md_lines)
    write_md(out_md_latest, md_lines)

    print(json.dumps({"status": "ok", "latest_json": str(out_json_latest), "latest_md": str(out_md_latest)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

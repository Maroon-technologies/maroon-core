#!/usr/bin/env python3
"""Inspect MAROON DB and embedding integrity for forensic-grade operations."""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def date_tag() -> str:
    return datetime.now(UTC).strftime("%Y_%m_%d")


def bq_json(project_id: str, sql: str) -> list[dict[str, Any]]:
    cmd = [
        "bq",
        f"--project_id={project_id}",
        "query",
        "--use_legacy_sql=false",
        "--format=json",
        sql,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        return []
    try:
        payload = json.loads(proc.stdout.strip() or "[]")
        return payload if isinstance(payload, list) else []
    except Exception:
        return []


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_md(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def build_args() -> argparse.Namespace:
    gft_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default="", help="Optional workspace root.")
    parser.add_argument("--gft-root", default=str(gft_default), help="Direct google_free_tier path.")
    parser.add_argument("--project-id", default="nanny-tech")
    parser.add_argument("--dataset", default="maroon_ops")
    return parser.parse_args()


def main() -> int:
    args = build_args()
    now = utc_now()
    stamp = date_tag()

    if args.root:
        root = Path(args.root).expanduser().resolve()
        gft_root = root / "Maroon-Core" / "google_free_tier"
    else:
        gft_root = Path(args.gft_root).expanduser().resolve()

    ops_dir = gft_root / "workspace" / "Maroon" / "Reports" / "Ops"

    latest_arch = bq_json(
        args.project_id,
        f"SELECT run_id, generated_at, systems_before, systems_after_compression, embedding_backend FROM `{args.project_id}.{args.dataset}.maroon_architecture_runs` ORDER BY generated_at DESC LIMIT 1",
    )
    lineage_stats = bq_json(
        args.project_id,
        f"SELECT COUNT(*) AS rows_total, COUNTIF(structural_review) AS structural_review_rows, ROUND(AVG(similarity_to_pillar),4) AS avg_similarity, ROUND(MIN(similarity_to_pillar),4) AS min_similarity, ROUND(MAX(similarity_to_pillar),4) AS max_similarity FROM `{args.project_id}.{args.dataset}.maroon_architecture_lineage`",
    )
    table_counts = bq_json(
        args.project_id,
        f"SELECT * FROM `{args.project_id}.{args.dataset}.executive_data_plane_overview`",
    )
    system_integrity = bq_json(
        args.project_id,
        f"SELECT COUNT(*) AS systems_total, COUNTIF(pillar_id IS NULL OR pillar_id = '') AS missing_pillar, COUNTIF(module_id IS NULL OR module_id = '') AS missing_module, COUNTIF(recommended_commercial_action IS NULL OR recommended_commercial_action = '') AS missing_action FROM `{args.project_id}.{args.dataset}.maroon_complete_picture_system_registry`",
    )
    ownership_integrity = bq_json(
        args.project_id,
        f"SELECT COUNT(*) AS ownership_rows, COUNTIF(owner IS NULL OR owner = '') AS missing_owner, COUNTIF(disclosure_policy IS NULL OR disclosure_policy = '') AS missing_disclosure, COUNT(DISTINCT owner) AS owners_distinct FROM `{args.project_id}.{args.dataset}.maroon_asset_ownership_registry`",
    )
    execution_integrity = bq_json(
        args.project_id,
        f"SELECT COUNT(*) AS tickets_total, COUNTIF(status='open') AS tickets_open, COUNTIF(priority='P1' AND status='open') AS p1_open FROM `{args.project_id}.{args.dataset}.maroon_execution_tickets`",
    )
    corpus_quality = bq_json(
        args.project_id,
        f"SELECT run_id, generated_at, docs_total, text_docs_total, core_docs_total, core_text_docs_total, priority_docs_total, priority_text_docs_total, line_coverage_pct, core_line_coverage_pct, priority_line_coverage_pct, avg_quality_score, core_avg_quality_score, open_gaps_total, critical_missing_total FROM `{args.project_id}.{args.dataset}.maroon_corpus_quality_overview`",
    )
    corpus_gap_stats = bq_json(
        args.project_id,
        f"SELECT COUNT(*) AS gap_rows, COUNTIF(severity='P0') AS p0_gaps, COUNTIF(severity='P1') AS p1_gaps FROM `{args.project_id}.{args.dataset}.maroon_corpus_gap_register`",
    )

    health_flags: list[str] = []

    arch_row = latest_arch[0] if latest_arch else {}
    lineage_row = lineage_stats[0] if lineage_stats else {}
    system_row = system_integrity[0] if system_integrity else {}
    ownership_row = ownership_integrity[0] if ownership_integrity else {}
    corpus_quality_row = corpus_quality[0] if corpus_quality else {}
    corpus_gap_row = corpus_gap_stats[0] if corpus_gap_stats else {}

    if not latest_arch:
        health_flags.append("missing_latest_architecture_run")
    if str(arch_row.get("embedding_backend", "")).lower() not in {"bigquery_vertex", "vertex", "gemini"}:
        health_flags.append("embedding_backend_not_vertex")
    if int(lineage_row.get("rows_total", 0) or 0) == 0:
        health_flags.append("lineage_rows_zero")
    if int(system_row.get("missing_pillar", 0) or 0) > 0:
        health_flags.append("systems_missing_pillar")
    if int(system_row.get("missing_action", 0) or 0) > 0:
        health_flags.append("systems_missing_commercial_action")
    if int(ownership_row.get("missing_owner", 0) or 0) > 0:
        health_flags.append("ownership_missing_owner")
    if int(ownership_row.get("missing_disclosure", 0) or 0) > 0:
        health_flags.append("ownership_missing_disclosure")
    if not corpus_quality:
        health_flags.append("missing_corpus_quality_overview")
    if float(corpus_quality_row.get("core_line_coverage_pct", 0) or 0) < 85.0:
        health_flags.append("core_corpus_line_coverage_below_threshold")
    if float(corpus_quality_row.get("priority_line_coverage_pct", 0) or 0) < 90.0:
        health_flags.append("priority_corpus_line_coverage_below_threshold")
    if float(corpus_quality_row.get("core_avg_quality_score", 0) or 0) < 55.0:
        health_flags.append("core_corpus_avg_quality_low")
    if int(corpus_gap_row.get("p0_gaps", 0) or 0) > 0:
        health_flags.append("corpus_p0_gaps_present")

    payload = {
        "generated_at": now,
        "project_id": args.project_id,
        "dataset": args.dataset,
        "latest_architecture_run": arch_row,
        "lineage_stats": lineage_row,
        "table_counts": table_counts[0] if table_counts else {},
        "system_integrity": system_row,
        "ownership_integrity": ownership_row,
        "execution_integrity": execution_integrity[0] if execution_integrity else {},
        "corpus_quality": corpus_quality_row,
        "corpus_gap_stats": corpus_gap_row,
        "health_flags": health_flags,
        "health_status": "PASS" if not health_flags else "REVIEW",
    }

    json_path = ops_dir / f"maroon_db_embedding_forensic_inspection_{stamp}.json"
    json_latest = ops_dir / "maroon_db_embedding_forensic_inspection_latest.json"
    write_json(json_path, payload)
    write_json(json_latest, payload)

    md_lines = [
        "# MAROON DB + Embedding Forensic Inspection",
        "",
        f"Generated: `{now}`",
        f"Status: `{payload['health_status']}`",
        "",
        "## Architecture/Embedding",
        "",
        f"- run_id: `{arch_row.get('run_id', 'n/a')}`",
        f"- embedding_backend: `{arch_row.get('embedding_backend', 'n/a')}`",
        f"- systems_before: `{arch_row.get('systems_before', 'n/a')}`",
        f"- systems_after_compression: `{arch_row.get('systems_after_compression', 'n/a')}`",
        "",
        "## Lineage Quality",
        "",
        f"- rows_total: `{lineage_row.get('rows_total', 'n/a')}`",
        f"- structural_review_rows: `{lineage_row.get('structural_review_rows', 'n/a')}`",
        f"- avg_similarity: `{lineage_row.get('avg_similarity', 'n/a')}`",
        f"- min_similarity: `{lineage_row.get('min_similarity', 'n/a')}`",
        f"- max_similarity: `{lineage_row.get('max_similarity', 'n/a')}`",
        "",
        "## System/Ownership Integrity",
        "",
        f"- missing_pillar: `{system_row.get('missing_pillar', 'n/a')}`",
        f"- missing_module: `{system_row.get('missing_module', 'n/a')}`",
        f"- missing_action: `{system_row.get('missing_action', 'n/a')}`",
        f"- ownership_rows: `{ownership_row.get('ownership_rows', 'n/a')}`",
        f"- owners_distinct: `{ownership_row.get('owners_distinct', 'n/a')}`",
        f"- missing_owner: `{ownership_row.get('missing_owner', 'n/a')}`",
        f"- missing_disclosure: `{ownership_row.get('missing_disclosure', 'n/a')}`",
        "",
        "## Corpus Quality",
        "",
        f"- line_coverage_pct: `{corpus_quality_row.get('line_coverage_pct', 'n/a')}`",
        f"- core_line_coverage_pct: `{corpus_quality_row.get('core_line_coverage_pct', 'n/a')}`",
        f"- priority_line_coverage_pct: `{corpus_quality_row.get('priority_line_coverage_pct', 'n/a')}`",
        f"- avg_quality_score: `{corpus_quality_row.get('avg_quality_score', 'n/a')}`",
        f"- core_avg_quality_score: `{corpus_quality_row.get('core_avg_quality_score', 'n/a')}`",
        f"- open_gaps_total: `{corpus_quality_row.get('open_gaps_total', 'n/a')}`",
        f"- critical_missing_total: `{corpus_quality_row.get('critical_missing_total', 'n/a')}`",
        f"- p0_gaps: `{corpus_gap_row.get('p0_gaps', 'n/a')}`",
        "",
        "## Health Flags",
        "",
    ]

    if health_flags:
        for flag in health_flags:
            md_lines.append(f"- {flag}")
    else:
        md_lines.append("- none")

    md_path = ops_dir / f"maroon_db_embedding_forensic_inspection_{stamp}.md"
    md_latest = ops_dir / "maroon_db_embedding_forensic_inspection_latest.md"
    write_md(md_path, md_lines)
    write_md(md_latest, md_lines)

    print(
        json.dumps(
            {
                "status": "ok",
                "health_status": payload["health_status"],
                "health_flags": health_flags,
                "json": str(json_latest),
                "md": str(md_latest),
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Build SQL-ready corpus inventory, quality snapshot, and gap register artifacts."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import stat
import subprocess
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


TEXT_EXTENSIONS = {
    ".md",
    ".txt",
    ".json",
    ".jsonl",
    ".csv",
    ".tsv",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".yaml",
    ".yml",
    ".toml",
    ".ini",
    ".html",
    ".xml",
    ".sql",
    ".cfg",
    ".conf",
    ".rst",
}

CORE_SCOPE_PREFIXES = (
    "Maroon-Core/google_free_tier/workspace/Maroon/",
    "Maroon-Core/google_free_tier/scripts/",
    "Maroon-Core/google_free_tier/sql/",
    "Maroon-Core/google_free_tier/firebase/functions/src/",
    "MaroonCLI/",
)

CORE_SCOPE_EXACT = {
    "MAROON.md",
    "NANA_BANANA_SPEC.md",
    "conversations.json",
    "chat.html",
    "Maroon_Discovery.txt",
}


def utc_now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def date_tag() -> str:
    return datetime.now(UTC).strftime("%Y_%m_%d")


def normalize_key(text: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in (text or "").strip().lower()).strip("_")


def safe_int(value: Any, fallback: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return fallback


def safe_float(value: Any, fallback: float = 0.0) -> float:
    try:
        return float(value)
    except Exception:
        return fallback


def load_tsv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in fieldnames})


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_md(path: Path, lines: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")


def run_checked(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip() or "unknown"
        raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(cmd)} :: {detail}")


def classify_scope(source_path: str) -> str:
    if source_path in CORE_SCOPE_EXACT:
        return "core"
    for prefix in CORE_SCOPE_PREFIXES:
        if source_path.startswith(prefix):
            return "core"
    return "extended"


def count_lines_with_timeout(path: Path, timeout_seconds: float) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["wc", "-l", str(path)],
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return -1, "timeout"
    except OSError:
        return -1, "error"

    if proc.returncode != 0:
        return -1, "error"
    out = proc.stdout.strip()
    if not out:
        return -1, "error"
    first = out.split()[0]
    try:
        return int(first), "ok"
    except Exception:
        return -1, "error"


def ensure_audit_inputs(*, root: Path, gft_root: Path, rebuild: bool) -> None:
    audit_dir = gft_root / "logs" / "corpus_full_audit"
    inventory_tsv = audit_dir / "file_inventory.tsv"
    line_counts_tsv = audit_dir / "text_line_counts.tsv"
    priority_tsv = audit_dir / "priority_corpus_manifest.tsv"

    if rebuild or not inventory_tsv.exists() or not line_counts_tsv.exists():
        run_checked(
            [
                "python3",
                str(gft_root / "scripts" / "corpus_audit_incremental.py"),
                "--root",
                str(root),
                "--rebuild-inventory",
                "--batch-size",
                "0",
                "--timeout-seconds",
                "2",
            ]
        )

    if rebuild or not priority_tsv.exists():
        run_checked(
            [
                "python3",
                str(gft_root / "scripts" / "build_priority_corpus_manifest.py"),
                "--root",
                str(root),
                "--out-tsv",
                str(priority_tsv),
                "--out-json",
                str(audit_dir / "priority_corpus_summary.json"),
            ]
        )


def should_hash_for_dedupe(path: str, *, is_text: bool, bytes_size: int, priority_weight: int) -> bool:
    if not is_text:
        return False
    if bytes_size <= 0:
        return False
    if priority_weight > 0:
        return True
    lower = path.lower()
    if "/maroon-core/google_free_tier/workspace/maroon/" in lower:
        return True
    if "/maroon-core/google_free_tier/sql/" in lower:
        return True
    if "/maroon-core/google_free_tier/scripts/" in lower:
        return True
    return False


def score_quality(
    *,
    is_text: bool,
    line_scan_status: str,
    priority_weight: int,
    duplicate_group_size: int,
    source_path: str,
    bytes_size: int,
) -> float:
    score = 0.0
    score += 25.0 if is_text else 10.0
    if line_scan_status == "ok":
        score += 20.0
    if priority_weight >= 200:
        score += 25.0
    elif priority_weight >= 120:
        score += 15.0
    elif priority_weight > 0:
        score += 8.0

    lower = source_path.lower()
    if "/workspace/maroon/canonical/" in lower:
        score += 10.0
    if "/reports/operating_registers/" in lower:
        score += 10.0

    if duplicate_group_size > 1:
        score -= min(20.0, float((duplicate_group_size - 1) * 5))
    if bytes_size > 2_000_000:
        score -= 5.0

    return max(0.0, min(100.0, round(score, 2)))


def main() -> int:
    gft_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default="", help="Optional workspace root; defaults to gft-root parent.")
    parser.add_argument("--gft-root", default=str(gft_default), help="Path to Maroon-Core/google_free_tier.")
    parser.add_argument("--ensure-audit-inputs", action="store_true", help="Generate missing audit inputs before build.")
    parser.add_argument("--rebuild-audit-inputs", action="store_true", help="Rebuild inventory/line/priority manifests.")
    parser.add_argument("--max-dedupe-bytes", type=int, default=250000)
    parser.add_argument("--max-dedupe-files", type=int, default=5000)
    parser.add_argument("--priority-line-fallback-limit", type=int, default=2000)
    parser.add_argument("--line-timeout-seconds", type=float, default=1.5)
    args = parser.parse_args()

    gft_root = Path(args.gft_root).expanduser().resolve()
    root = Path(args.root).expanduser().resolve() if args.root else gft_root.parents[1]

    if args.ensure_audit_inputs or args.rebuild_audit_inputs:
        ensure_audit_inputs(root=root, gft_root=gft_root, rebuild=args.rebuild_audit_inputs)

    audit_dir = gft_root / "logs" / "corpus_full_audit"
    ops_dir = gft_root / "workspace" / "Maroon" / "Reports" / "Ops"
    inventory_tsv = audit_dir / "file_inventory.tsv"
    line_counts_tsv = audit_dir / "text_line_counts.tsv"
    priority_tsv = audit_dir / "priority_corpus_manifest.tsv"
    critical_hashes_tsv = audit_dir / "critical_hashes.tsv"
    state_json = audit_dir / "state.json"

    inventory_rows = load_tsv_rows(inventory_tsv)
    line_rows = load_tsv_rows(line_counts_tsv)
    priority_rows = load_tsv_rows(priority_tsv)
    critical_rows = load_tsv_rows(critical_hashes_tsv)
    state_payload = (
        json.loads(state_json.read_text(encoding="utf-8")) if state_json.exists() else {}
    )

    line_by_path: dict[str, tuple[int, str]] = {}
    for row in line_rows:
        path = row.get("path", "").strip()
        if not path:
            continue
        line_by_path[path] = (safe_int(row.get("line_count", -1), -1), row.get("status", "").strip().lower())

    priority_by_path: dict[str, dict[str, str]] = {}
    for row in priority_rows:
        path = row.get("path", "").strip()
        if not path:
            continue
        priority_by_path[path] = row

    dedupe_candidates: list[tuple[str, Path]] = []
    for row in inventory_rows:
        source_path = row.get("path", "").strip()
        if not source_path:
            continue
        bytes_size = safe_int(row.get("bytes", 0), 0)
        ext = Path(source_path).suffix.lower()
        is_text = ext in TEXT_EXTENSIONS
        p_row = priority_by_path.get(source_path, {})
        priority_weight = safe_int(p_row.get("priority_weight", 0), 0)
        if bytes_size > args.max_dedupe_bytes:
            continue
        if not should_hash_for_dedupe(
            source_path,
            is_text=is_text,
            bytes_size=bytes_size,
            priority_weight=priority_weight,
        ):
            continue
        abs_path = root / source_path
        if not abs_path.exists() or not abs_path.is_file():
            continue
        if abs_path.is_symlink():
            continue
        try:
            st_mode = abs_path.stat().st_mode
        except OSError:
            continue
        if not stat.S_ISREG(st_mode):
            continue
        dedupe_candidates.append((source_path, abs_path))

    dedupe_candidates.sort(key=lambda item: item[0])
    dedupe_candidates = dedupe_candidates[: max(0, args.max_dedupe_files)]

    hash_by_path: dict[str, str] = {}
    groups: dict[str, list[str]] = defaultdict(list)
    for source_path, abs_path in dedupe_candidates:
        try:
            h = hashlib.sha256()
            with abs_path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    h.update(chunk)
            digest = h.hexdigest()
        except Exception:
            continue
        hash_by_path[source_path] = digest
        groups[digest].append(source_path)

    dup_size_by_path: dict[str, int] = {}
    for digest, paths in groups.items():
        size = len(paths)
        if size <= 1:
            continue
        for source_path in paths:
            dup_size_by_path[source_path] = size

    rows_out: list[dict[str, Any]] = []
    gaps_out: list[dict[str, Any]] = []

    now = utc_now()
    run_entropy = hashlib.sha256(
        f"{now}|{len(inventory_rows)}|{len(line_rows)}|{len(priority_rows)}".encode("utf-8")
    ).hexdigest()[:12]
    run_id = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + run_entropy
    fallback_line_scans_used = 0

    for row in inventory_rows:
        source_path = row.get("path", "").strip()
        if not source_path:
            continue
        bytes_size = safe_int(row.get("bytes", 0), 0)
        mtime_utc = row.get("mtime_utc", "").strip()
        ext = Path(source_path).suffix.lower()
        is_text = ext in TEXT_EXTENSIONS
        scope_class = classify_scope(source_path)

        p_row = priority_by_path.get(source_path, {})
        priority_weight = safe_int(p_row.get("priority_weight", 0), 0)
        source_tags = p_row.get("source_tags", "")

        line_count, line_status = line_by_path.get(source_path, (-1, "missing"))
        if (
            is_text
            and priority_weight >= 120
            and line_status != "ok"
            and fallback_line_scans_used < max(0, args.priority_line_fallback_limit)
        ):
            abs_path = root / source_path
            if abs_path.exists() and abs_path.is_file():
                fallback_lines, fallback_status = count_lines_with_timeout(
                    abs_path, timeout_seconds=max(0.1, args.line_timeout_seconds)
                )
                fallback_line_scans_used += 1
                if fallback_status == "ok":
                    line_count = fallback_lines
                    line_status = "ok"
                    line_by_path[source_path] = (line_count, line_status)

        dedupe_hash = hash_by_path.get(source_path, "")
        dup_size = dup_size_by_path.get(source_path, 1)

        gap_flags: list[str] = []
        if is_text and line_status != "ok":
            gap_flags.append("line_scan_missing")
        if priority_weight >= 180 and is_text and line_count <= 0:
            gap_flags.append("priority_missing_line_count")
        if dup_size > 1:
            gap_flags.append("duplicate_content")

        quality_score = score_quality(
            is_text=is_text,
            line_scan_status=line_status,
            priority_weight=priority_weight,
            duplicate_group_size=dup_size,
            source_path=source_path,
            bytes_size=bytes_size,
        )

        doc_id = "DOC-" + hashlib.sha256(source_path.encode("utf-8")).hexdigest()[:12].upper()
        rows_out.append(
            {
                "doc_id": doc_id,
                "source_path": source_path,
                "bytes": bytes_size,
                "mtime_utc": mtime_utc,
                "extension": ext,
                "is_text": "true" if is_text else "false",
                "priority_weight": priority_weight,
                "source_tags": source_tags,
                "scope_class": scope_class,
                "line_count": line_count if line_count >= 0 else "",
                "line_scan_status": line_status,
                "dedupe_hash": dedupe_hash,
                "duplicate_group_size": dup_size,
                "quality_score": quality_score,
                "gap_flags": "|".join(gap_flags),
                "last_scanned_utc": now,
            }
        )

        if "line_scan_missing" in gap_flags and priority_weight >= 120:
            gaps_out.append(
                {
                    "severity": "P1",
                    "gap_type": "lineage_coverage",
                    "source_path": source_path,
                    "detail": "Priority corpus file missing successful line scan metadata.",
                    "recommended_action": "Re-run corpus_audit_incremental with batch-size 0.",
                    "status": "open",
                }
            )
        if "duplicate_content" in gap_flags and dup_size >= 3:
            gaps_out.append(
                {
                    "severity": "P2",
                    "gap_type": "dedupe_required",
                    "source_path": source_path,
                    "detail": f"Duplicate content group detected (size={dup_size}).",
                    "recommended_action": "Keep canonical source and archive aliases.",
                    "status": "open",
                }
            )

    for row in critical_rows:
        if row.get("status", "").strip().upper() == "MISSING":
            source_path = row.get("path", "").strip()
            gaps_out.append(
                {
                    "severity": "P0",
                    "gap_type": "critical_missing",
                    "source_path": source_path,
                    "detail": "Critical corpus target missing from workspace snapshot.",
                    "recommended_action": "Restore source and regenerate canonical snapshot.",
                    "status": "open",
                }
            )

    if not bool(state_payload.get("complete", False)):
        gaps_out.append(
            {
                "severity": "P1",
                "gap_type": "scan_incomplete",
                "source_path": "logs/corpus_full_audit/state.json",
                "detail": "Incremental text-line scan is not complete.",
                "recommended_action": "Run corpus_audit_incremental.py with --batch-size 0.",
                "status": "open",
            }
        )

    gap_rows_indexed: list[dict[str, Any]] = []
    for idx, row in enumerate(gaps_out, start=1):
        gap_id = f"CGAP-{idx:04d}"
        gap_rows_indexed.append(
            {
                "gap_id": gap_id,
                "severity": row["severity"],
                "gap_type": row["gap_type"],
                "source_path": row["source_path"],
                "detail": row["detail"],
                "recommended_action": row["recommended_action"],
                "status": row["status"],
                "created_at_utc": now,
            }
        )

    docs_total = len(rows_out)
    text_docs_total = sum(1 for row in rows_out if row["is_text"] == "true")
    core_docs_total = sum(1 for row in rows_out if row["scope_class"] == "core")
    core_text_docs_total = sum(
        1 for row in rows_out if row["scope_class"] == "core" and row["is_text"] == "true"
    )
    priority_docs_total = sum(1 for row in rows_out if safe_int(row["priority_weight"], 0) > 0)
    priority_text_docs_total = sum(
        1
        for row in rows_out
        if row["is_text"] == "true" and safe_int(row["priority_weight"], 0) > 0
    )
    scanned_text_docs = sum(
        1 for row in rows_out if row["is_text"] == "true" and row["line_scan_status"] == "ok"
    )
    core_scanned_text_docs = sum(
        1
        for row in rows_out
        if row["scope_class"] == "core" and row["is_text"] == "true" and row["line_scan_status"] == "ok"
    )
    priority_scanned_text_docs = sum(
        1
        for row in rows_out
        if row["is_text"] == "true"
        and safe_int(row["priority_weight"], 0) > 0
        and row["line_scan_status"] == "ok"
    )
    line_coverage_pct = round((100.0 * scanned_text_docs / text_docs_total), 2) if text_docs_total else 0.0
    core_line_coverage_pct = (
        round((100.0 * core_scanned_text_docs / core_text_docs_total), 2) if core_text_docs_total else 0.0
    )
    priority_line_coverage_pct = (
        round((100.0 * priority_scanned_text_docs / priority_text_docs_total), 2)
        if priority_text_docs_total
        else 0.0
    )
    duplicate_groups_total = sum(1 for _, members in groups.items() if len(members) > 1)
    duplicate_docs_total = sum(max(0, len(members) - 1) for _, members in groups.items() if len(members) > 1)
    critical_missing_total = sum(
        1 for row in critical_rows if row.get("status", "").strip().upper() == "MISSING"
    )
    avg_quality_score = round(
        sum(safe_float(row["quality_score"], 0.0) for row in rows_out) / docs_total, 2
    ) if docs_total else 0.0
    core_avg_quality_score = round(
        sum(safe_float(row["quality_score"], 0.0) for row in rows_out if row["scope_class"] == "core")
        / core_docs_total,
        2,
    ) if core_docs_total else 0.0

    summary = {
        "run_id": run_id,
        "generated_at": now,
        "docs_total": docs_total,
        "text_docs_total": text_docs_total,
        "core_docs_total": core_docs_total,
        "core_text_docs_total": core_text_docs_total,
        "priority_docs_total": priority_docs_total,
        "priority_text_docs_total": priority_text_docs_total,
        "line_coverage_pct": line_coverage_pct,
        "core_line_coverage_pct": core_line_coverage_pct,
        "priority_line_coverage_pct": priority_line_coverage_pct,
        "duplicate_groups_total": duplicate_groups_total,
        "duplicate_docs_total": duplicate_docs_total,
        "critical_missing_total": critical_missing_total,
        "open_gaps_total": len(gap_rows_indexed),
        "avg_quality_score": avg_quality_score,
        "core_avg_quality_score": core_avg_quality_score,
        "priority_line_fallback_scans_used": fallback_line_scans_used,
        "scan_state_complete": bool(state_payload.get("complete", False)),
        "scan_state_processed": safe_int(state_payload.get("processed", 0), 0),
        "scan_state_candidates_total": safe_int(state_payload.get("candidates_total", 0), 0),
        "sources": {
            "inventory_tsv": str(inventory_tsv),
            "line_counts_tsv": str(line_counts_tsv),
            "priority_manifest_tsv": str(priority_tsv),
            "critical_hashes_tsv": str(critical_hashes_tsv),
            "state_json": str(state_json),
        },
    }

    tag = date_tag()
    inventory_csv = ops_dir / f"maroon_corpus_file_inventory_{tag}.csv"
    inventory_csv_latest = ops_dir / "maroon_corpus_file_inventory_latest.csv"
    gap_csv = ops_dir / f"maroon_corpus_gap_register_{tag}.csv"
    gap_csv_latest = ops_dir / "maroon_corpus_gap_register_latest.csv"
    snapshot_json = ops_dir / f"maroon_corpus_quality_snapshot_{tag}.json"
    snapshot_json_latest = ops_dir / "maroon_corpus_quality_snapshot_latest.json"
    snapshot_md = ops_dir / f"maroon_corpus_quality_snapshot_{tag}.md"
    snapshot_md_latest = ops_dir / "maroon_corpus_quality_snapshot_latest.md"

    inventory_fields = [
        "doc_id",
        "source_path",
        "bytes",
        "mtime_utc",
        "extension",
        "is_text",
        "priority_weight",
        "source_tags",
        "scope_class",
        "line_count",
        "line_scan_status",
        "dedupe_hash",
        "duplicate_group_size",
        "quality_score",
        "gap_flags",
        "last_scanned_utc",
    ]
    gap_fields = [
        "gap_id",
        "severity",
        "gap_type",
        "source_path",
        "detail",
        "recommended_action",
        "status",
        "created_at_utc",
    ]

    rows_out.sort(key=lambda row: row["source_path"])
    gap_rows_indexed.sort(key=lambda row: (row["severity"], row["gap_type"], row["source_path"]))
    write_csv(inventory_csv, rows_out, inventory_fields)
    write_csv(inventory_csv_latest, rows_out, inventory_fields)
    write_csv(gap_csv, gap_rows_indexed, gap_fields)
    write_csv(gap_csv_latest, gap_rows_indexed, gap_fields)
    write_json(snapshot_json, summary)
    write_json(snapshot_json_latest, summary)

    md_lines = [
        "# MAROON Corpus Quality Snapshot",
        "",
        f"- Run ID: `{run_id}`",
        f"- Generated: `{now}`",
        f"- Docs total: `{docs_total}`",
        f"- Text docs: `{text_docs_total}`",
        f"- Core docs: `{core_docs_total}`",
        f"- Core text docs: `{core_text_docs_total}`",
        f"- Priority docs: `{priority_docs_total}`",
        f"- Priority text docs: `{priority_text_docs_total}`",
        f"- Line coverage: `{line_coverage_pct}%`",
        f"- Core line coverage: `{core_line_coverage_pct}%`",
        f"- Priority line coverage: `{priority_line_coverage_pct}%`",
        f"- Avg quality score: `{avg_quality_score}`",
        f"- Core avg quality score: `{core_avg_quality_score}`",
        f"- Priority fallback line scans used: `{fallback_line_scans_used}`",
        f"- Duplicate groups: `{duplicate_groups_total}`",
        f"- Duplicate docs (excluding primary): `{duplicate_docs_total}`",
        f"- Open gaps: `{len(gap_rows_indexed)}`",
        f"- Critical missing files: `{critical_missing_total}`",
        "",
        "## Source Artifacts",
        "",
        f"- `{inventory_tsv}`",
        f"- `{line_counts_tsv}`",
        f"- `{priority_tsv}`",
        f"- `{critical_hashes_tsv}`",
        "",
        "## Output Artifacts",
        "",
        f"- `{inventory_csv_latest}`",
        f"- `{gap_csv_latest}`",
        f"- `{snapshot_json_latest}`",
    ]
    write_md(snapshot_md, md_lines)
    write_md(snapshot_md_latest, md_lines)

    print(
        json.dumps(
            {
                "status": "ok",
                "run_id": run_id,
                "docs_total": docs_total,
                "text_docs_total": text_docs_total,
                "line_coverage_pct": line_coverage_pct,
                "open_gaps_total": len(gap_rows_indexed),
                "outputs": {
                    "inventory_csv_latest": str(inventory_csv_latest),
                    "gap_csv_latest": str(gap_csv_latest),
                    "snapshot_json_latest": str(snapshot_json_latest),
                    "snapshot_md_latest": str(snapshot_md_latest),
                },
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

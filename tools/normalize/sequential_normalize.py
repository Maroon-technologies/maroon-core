#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import yaml
except Exception as exc:  # pragma: no cover
    raise SystemExit("Missing dependency: pyyaml. Install with: python3 -m pip install pyyaml") from exc


@dataclass
class Config:
    input_root: Path
    include_extensions: List[str]
    exclude_paths: List[str]
    allowed_types: List[str]
    allow_rename: bool
    report_dir: Path
    report_prefix: str


def load_config(path: Path, workspace_root: Path) -> Config:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))

    input_root = Path(data["scope"]["input_root"])
    if not input_root.is_absolute():
        input_root = (workspace_root / input_root).resolve()

    include_extensions = data["scope"].get("include_extensions", [".md"])
    exclude_paths = data["scope"].get("exclude_paths", [])

    allowed_types = data["classification"]["allowed_types"]
    allow_rename = bool(data["naming"].get("allow_rename", False))

    report_dir = Path(data["output"]["report_dir"])
    if not report_dir.is_absolute():
        report_dir = (workspace_root / report_dir).resolve()

    report_prefix = data["output"].get("report_prefix", "REPORT_SEQUENTIAL")

    return Config(
        input_root=input_root,
        include_extensions=include_extensions,
        exclude_paths=exclude_paths,
        allowed_types=allowed_types,
        allow_rename=allow_rename,
        report_dir=report_dir,
        report_prefix=report_prefix,
    )


def should_exclude(path: Path, exclude_paths: List[str], workspace_root: Path) -> bool:
    rel = str(path)
    try:
        rel = str(path.relative_to(workspace_root))
    except ValueError:
        pass
    for ex in exclude_paths:
        if ex and ex.strip() in rel:
            return True
    return False


def iter_files(config: Config, workspace_root: Path) -> List[Path]:
    files: List[Path] = []
    for root, _dirs, filenames in os.walk(config.input_root):
        for name in filenames:
            ext = os.path.splitext(name)[1].lower()
            if ext not in config.include_extensions:
                continue
            full = Path(root) / name
            if should_exclude(full, config.exclude_paths, workspace_root):
                continue
            files.append(full)
    return sorted(files)


def parse_frontmatter(text: str) -> Dict[str, Any]:
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    fm = parts[1]
    try:
        return yaml.safe_load(fm) or {}
    except Exception:
        return {}


def sanitize_snake(name: str) -> str:
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return name or "untitled"


def extract_json_block(text: str) -> Optional[Dict[str, Any]]:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except Exception:
        return None


def call_model(model: str, prompt: str) -> str:
    proc = subprocess.run(
        ["ollama", "run", model],
        input=prompt.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="ignore")
        raise RuntimeError(f"ollama run failed: {err.strip()}")
    return proc.stdout.decode("utf-8", errors="ignore")


def build_prompt(content: str, filename: str, thread_title: str, allowed_types: List[str]) -> str:
    return f"""
You are running in STRICT SEQUENTIAL NORMALIZATION MODE.

Rules:
- Process ONE file at a time
- Do NOT rename files
- Do NOT modify content
- ONLY analyze, classify, and propose changes
- Output JSON only

Allowed content types:
{', '.join(allowed_types)}

Filename: {filename}
Thread title: {thread_title}

Return JSON with fields:
- detected_types: array (subset of allowed types)
- canonical_name: snake_case proposal
- rename_required: true/false
- proposed_thread_title: string
- reasoning: string
- truth_teller_flags: array of risks or possible misstatements

Content (verbatim):
"""
{content}
"""
"""


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: sequential_normalize.py <config.yaml>", file=sys.stderr)
        return 1

    workspace_root = Path(__file__).resolve().parents[3]
    config_path = Path(sys.argv[1]).resolve()
    config = load_config(config_path, workspace_root)

    files = iter_files(config, workspace_root)
    total = len(files)

    run_ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    out_dir = config.report_dir / f"SEQUENTIAL_{run_ts}"
    out_dir.mkdir(parents=True, exist_ok=True)

    report_path = out_dir / f"{config.report_prefix}_{run_ts}.md"
    csv_path = out_dir / "rename_map.csv"

    model = os.environ.get("MAROON_SEQUENTIAL_MODEL", "qwen2.5:0.5b")

    report_lines: List[str] = []
    report_lines.append("# DeepSeek Sequential Normalization Report")
    report_lines.append("")
    report_lines.append(f"Generated: {datetime.now(timezone.utc).isoformat(timespec='seconds')}")
    report_lines.append(f"Input root: {config.input_root}")
    report_lines.append(f"Model: {model}")
    report_lines.append(f"Allow rename: {config.allow_rename}")
    report_lines.append("")

    with open(csv_path, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([
            "original_filename",
            "proposed_filename",
            "original_thread_title",
            "proposed_thread_title",
            "detected_types",
            "rename_required",
            "reasoning",
        ])

        for idx, path in enumerate(files, 1):
            content = path.read_text(encoding="utf-8", errors="ignore")
            fm = parse_frontmatter(content)
            thread_title = ""
            if isinstance(fm, dict):
                thread = fm.get("thread") or {}
                if isinstance(thread, dict):
                    thread_title = thread.get("title") or ""
            thread_title = thread_title or path.stem
            rel_path = str(path.relative_to(workspace_root))

            prompt = build_prompt(content, rel_path, thread_title, config.allowed_types)

            try:
                raw = call_model(model, prompt)
                result = extract_json_block(raw) or {}
                detected_types = result.get("detected_types", [])
                if not isinstance(detected_types, list):
                    detected_types = []
                canonical_name = result.get("canonical_name") or sanitize_snake(thread_title)
                rename_required = bool(result.get("rename_required", False))
                proposed_thread_title = result.get("proposed_thread_title") or canonical_name
                reasoning = result.get("reasoning", "")
                truth_flags = result.get("truth_teller_flags", [])
                if not isinstance(truth_flags, list):
                    truth_flags = []
            except Exception as exc:
                detected_types = []
                canonical_name = sanitize_snake(thread_title)
                rename_required = False
                proposed_thread_title = thread_title
                reasoning = f"error: {exc}"
                truth_flags = []

            proposed_filename = f"{path.stem}__{canonical_name}.maroon.md" if rename_required else path.name

            report_lines.append(f"## Strand {idx} / {total}")
            report_lines.append("")
            report_lines.append("Original filename:")
            report_lines.append(rel_path)
            report_lines.append("")
            report_lines.append("Original thread_title:")
            report_lines.append(f"\"{thread_title}\"")
            report_lines.append("")
            report_lines.append("Detected content types:")
            if detected_types:
                for t in detected_types:
                    report_lines.append(f"- {t}")
            else:
                report_lines.append("- unknown")
            report_lines.append("")
            report_lines.append("Canonical name proposed:")
            report_lines.append(canonical_name)
            report_lines.append("")
            report_lines.append("Reasoning:")
            report_lines.append(reasoning or "n/a")
            report_lines.append("")
            report_lines.append("Rename required:")
            report_lines.append("YES" if rename_required else "NO")
            report_lines.append("")
            report_lines.append("Changes proposed:")
            report_lines.append(f"- filename: {path.name} -> {proposed_filename}")
            report_lines.append(f"- metadata.thread_title: \"{thread_title}\" -> \"{proposed_thread_title}\"")
            report_lines.append("")
            report_lines.append("Truth Teller flags:")
            if truth_flags:
                for f in truth_flags:
                    report_lines.append(f"- {f}")
            else:
                report_lines.append("- none")
            report_lines.append("")
            report_lines.append("Status:")
            report_lines.append("DRY-RUN ONLY — no changes applied")
            report_lines.append("")

            writer.writerow([
                rel_path,
                proposed_filename,
                thread_title,
                proposed_thread_title,
                "|".join(detected_types),
                "YES" if rename_required else "NO",
                reasoning,
            ])

    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    print(str(report_path))
    print(str(csv_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib import request
import subprocess

try:
    import yaml
except Exception as exc:
    raise SystemExit("Missing dependency: pyyaml. Install with: python3 -m pip install pyyaml") from exc


def resolve_workspace_root() -> Path:
    return Path(__file__).resolve().parents[3]


def resolve_clean_dir(workspace_root: Path) -> Path:
    env = os.environ.get("MAROON_INGEST_DIR")
    if env:
        return Path(env).expanduser().resolve()
    return (workspace_root / "maroon_ingest").resolve()


def resolve_raw_dir(workspace_root: Path) -> Path:
    env = os.environ.get("MAROON_INGEST_RAW_DIR")
    if env:
        return Path(env).expanduser().resolve()
    return (workspace_root / "maroon_ingest_raw").resolve()


def load_deepseek_actions(workspace_root: Path) -> Dict[str, str]:
    actions_map: Dict[str, Dict[str, str]] = {}
    for folder in ["requests/pending", "requests/processed"]:
        req_dir = workspace_root / "Maroon-Core" / folder
        if not req_dir.exists():
            continue
        for path in req_dir.glob("*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                rel = data.get("source_relpath")
                actions = (data.get("actions_text") or "").strip()
                created = data.get("created_at") or ""
                if rel and actions:
                    existing = actions_map.get(rel)
                    if not existing or created > existing["created_at"]:
                        actions_map[rel] = {"actions": actions, "created_at": created}
            except Exception:
                continue
    return {k: v["actions"] for k, v in actions_map.items()}


def extract_thread(raw_text: str) -> str:
    if "<<<BEGIN THREAD>>>" in raw_text and "<<<END THREAD>>>" in raw_text:
        return raw_text.split("<<<BEGIN THREAD>>>", 1)[1].split("<<<END THREAD>>>", 1)[0].strip()
    return raw_text.strip()


def parse_frontmatter(text: str) -> Dict[str, Any]:
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        return yaml.safe_load(parts[1]) or {}
    except Exception:
        return {}


def sanitize_snake(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text or "untitled"


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def call_openai(prompt: str) -> Dict[str, Any]:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    model = os.environ.get("MAROON_CLEAN_MODEL", "gpt-4.1-mini")

    payload = {
        "model": model,
        "input": prompt,
    }

    req = request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    with request.urlopen(req) as resp:  # nosec B310
        data = json.loads(resp.read().decode("utf-8"))
    return data


def call_ollama(prompt: str) -> Dict[str, Any]:
    model = os.environ.get("MAROON_CLEAN_MODEL", "qwen2.5:0.5b")
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
    text = proc.stdout.decode("utf-8", errors="ignore")
    return {"output_text": text}


def extract_text_from_response(resp: Dict[str, Any]) -> str:
    if "output" in resp:
        parts: List[str] = []
        for item in resp.get("output", []):
            if item.get("type") != "message":
                continue
            for c in item.get("content", []):
                text = c.get("text") if isinstance(c, dict) else None
                if text:
                    parts.append(text)
        if parts:
            return "\n".join(parts)
    if "output_text" in resp and isinstance(resp["output_text"], str):
        return resp["output_text"]
    return json.dumps(resp)


def extract_json_block(text: str) -> Dict[str, Any]:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return {}
    try:
        return json.loads(match.group(0))
    except Exception:
        return {}


def build_prompt(thread_text: str, original_title: str, deepseek_actions: str | None) -> str:
    return f"""
You are a normalization engine. Output JSON only.

Goals:
- Preserve verbatim content (do NOT rewrite the thread content)
- Produce a Harvard-grade, professional normalization summary with plain-language clarity
- Propose a canonical snake_case name
- Classify content type and tags
- Flag possible truth risks (Truth Teller flags)
- Leave explicit notes for a downstream DeepSeek agent

Return JSON with fields:
- clean_title
- canonical_name
- possible_types (array)
- tags (array)
- summary (string)
- decisions (array)
- open_questions (array)
- actions (array)
- truth_teller_flags (array)
- changes_made (array)
- notes_for_deepseek (array)
- recommendations_for_deepseek (array)

Original thread title: {original_title}

DeepSeek guidance (from raw analysis):
{deepseek_actions or "none"}

Thread content:
"""
{thread_text}
"""
"""


def main() -> int:
    workspace_root = resolve_workspace_root()
    raw_dir = resolve_raw_dir(workspace_root)
    clean_dir = resolve_clean_dir(workspace_root)
    clean_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = clean_dir / "clean_manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {}

    raw_files = sorted(raw_dir.rglob("*.maroon.md"))
    deepseek_actions_map = load_deepseek_actions(workspace_root)
    index_path = clean_dir / "clean_index.json"
    if index_path.exists():
        index = json.loads(index_path.read_text(encoding="utf-8"))
    else:
        index = {}
    processed = 0

    for raw_path in raw_files:
        raw_text = raw_path.read_text(encoding="utf-8", errors="ignore")
        raw_hash = sha256_text(raw_text)
        if manifest.get(str(raw_path)) == raw_hash:
            continue

        fm = parse_frontmatter(raw_text)
        original_title = ""
        if isinstance(fm, dict):
            thread = fm.get("thread") or {}
            if isinstance(thread, dict):
                original_title = thread.get("title") or ""
        original_title = original_title or raw_path.stem

        thread_text = extract_thread(raw_text)
        rel_raw = str(raw_path.relative_to(workspace_root)) if raw_path.is_absolute() else str(raw_path)
        ds_actions = deepseek_actions_map.get(rel_raw)

        prompt = build_prompt(thread_text, original_title, ds_actions)
        backend = os.environ.get("MAROON_CLEAN_BACKEND", "ollama").strip().lower()
        if backend == "openai":
            resp = call_openai(prompt)
        else:
            resp = call_ollama(prompt)
        resp_text = extract_text_from_response(resp)
        result = extract_json_block(resp_text)

        clean_title = result.get("clean_title") or original_title
        canonical_name = result.get("canonical_name") or sanitize_snake(clean_title)
        possible_types = result.get("possible_types", []) if isinstance(result.get("possible_types"), list) else []
        tags = result.get("tags", []) if isinstance(result.get("tags"), list) else []
        summary = result.get("summary", "")
        decisions = result.get("decisions", []) if isinstance(result.get("decisions"), list) else []
        open_questions = result.get("open_questions", []) if isinstance(result.get("open_questions"), list) else []
        actions = result.get("actions", []) if isinstance(result.get("actions"), list) else []
        truth_flags = result.get("truth_teller_flags", []) if isinstance(result.get("truth_teller_flags"), list) else []
        changes_made = result.get("changes_made", []) if isinstance(result.get("changes_made"), list) else []
        notes_for_deepseek = result.get("notes_for_deepseek", []) if isinstance(result.get("notes_for_deepseek"), list) else []
        recommendations_for_deepseek = result.get("recommendations_for_deepseek", []) if isinstance(result.get("recommendations_for_deepseek"), list) else []

        # derive date from raw file path or fallback to today
        try:
            date_part = raw_path.name.split("__", 1)[0]
            dt = datetime.strptime(date_part, "%Y-%m-%d")
        except Exception:
            dt = datetime.now(timezone.utc)
        year = dt.strftime("%Y")
        month = dt.strftime("%m")
        date = dt.strftime("%Y-%m-%d")

        out_folder = clean_dir / year / month
        out_folder.mkdir(parents=True, exist_ok=True)
        out_filename = f"{date}__{canonical_name}__chatgpt.maroon.md"
        out_path = out_folder / out_filename

        metadata = []
        metadata.append("---")
        metadata.append("maroon_version: 1.0")
        metadata.append("phase: phase_0_discovery")
        metadata.append(f"ingested_at: {datetime.now(timezone.utc).isoformat(timespec='seconds')}Z")
        metadata.append("ingest_stage: clean")
        metadata.append("source:")
        metadata.append("  system: chatgpt")
        metadata.append("  channel: export")
        metadata.append("thread:")
        metadata.append(f"  title: \"{clean_title.replace('"', '\\"')}\"")
        metadata.append(f"  original_title: \"{original_title.replace('"', '\\"')}\"")
        metadata.append(f"  original_filename: \"{raw_path.name}\"")
        metadata.append(f"  canonical_name: {canonical_name}")
        metadata.append("raw_reference:")
        metadata.append(f"  path: \"{str(raw_path)}\"")
        metadata.append(f"  sha256: {raw_hash}")
        metadata.append("content_classification:")
        if possible_types:
            metadata.append("  possible_types:")
            for t in possible_types:
                metadata.append(f"    - {t}")
        else:
            metadata.append("  possible_types: []")
        metadata.append("  certainty: low")
        if tags:
            metadata.append("tags:")
            for t in tags:
                metadata.append(f"  - {t}")
        else:
            metadata.append("tags: []")
        metadata.append("assumptions:")
        metadata.append("  - content preserved verbatim")
        metadata.append("  - normalization added, no raw content discarded")
        metadata.append("instructions_to_downstream_ai:")
        metadata.append("  - use normalized sections for quick triage")
        metadata.append("  - preserve verbatim thread for source of truth")
        metadata.append("  - review notes_for_deepseek and recommendations")
        metadata.append("---")
        metadata.append("")
        metadata.append("# Normalized Summary")
        metadata.append(summary or "")
        metadata.append("")
        metadata.append("# Changes Made")
        if changes_made:
            for c in changes_made:
                metadata.append(f"- {c}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Key Decisions")
        if decisions:
            for d in decisions:
                metadata.append(f"- {d}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Open Questions")
        if open_questions:
            for q in open_questions:
                metadata.append(f"- {q}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Actions")
        if actions:
            for a in actions:
                metadata.append(f"- {a}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Notes for DeepSeek")
        if notes_for_deepseek:
            for n in notes_for_deepseek:
                metadata.append(f"- {n}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Recommendations for DeepSeek")
        if recommendations_for_deepseek:
            for r in recommendations_for_deepseek:
                metadata.append(f"- {r}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Truth Teller Flags")
        if truth_flags:
            for f in truth_flags:
                metadata.append(f"- {f}")
        else:
            metadata.append("- none")
        metadata.append("")
        metadata.append("# Verbatim Thread Content")
        metadata.append("")
        metadata.append("<<<BEGIN THREAD>>>")
        metadata.append(thread_text)
        metadata.append("<<<END THREAD>>>")
        metadata.append("")

        if ds_actions:
            metadata.append("# DeepSeek Guidance From Raw")
            metadata.append(ds_actions)
            metadata.append("")

        out_path.write_text("\n".join(metadata), encoding="utf-8")

        manifest[str(raw_path)] = raw_hash
        index[str(raw_path)] = {
            "clean_path": str(out_path),
            "raw_sha256": raw_hash,
            "canonical_name": canonical_name,
            "clean_title": clean_title,
            "types": possible_types,
            "tags": tags,
        }
        processed += 1

        log_path = clean_dir / "UPLOAD_LOG.md"
        with log_path.open("a", encoding="utf-8") as f:
            f.write(f"- {datetime.now(timezone.utc).isoformat(timespec='seconds')}Z | cleaned {raw_path} -> {out_path}\n")

    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    index_path.write_text(json.dumps(index, indent=2), encoding="utf-8")

    print(f"Cleaned: {processed} files")
    print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

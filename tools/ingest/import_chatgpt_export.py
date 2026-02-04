#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


def sanitize(text: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9\-]+", "-", text.lower())
    cleaned = re.sub(r"-+", "-", cleaned).strip("-")
    return cleaned or "untitled"


def resolve_workspace_root() -> Path:
    return Path(__file__).resolve().parents[3]


def resolve_raw_dir(workspace_root: Path) -> Path:
    env = os.environ.get("MAROON_INGEST_RAW_DIR")
    if env:
        return Path(env).expanduser().resolve()
    return (workspace_root / "maroon_ingest_raw").resolve()


def extract_text(content: Dict[str, Any]) -> str:
    if not content:
        return ""
    parts = content.get("parts")
    if isinstance(parts, list):
        return "\n".join(str(p) for p in parts if p is not None).strip()
    # fallback
    return json.dumps(content, ensure_ascii=False, indent=2).strip()


def build_thread_text(conv: Dict[str, Any]) -> str:
    mapping = conv.get("mapping", {})
    messages: List[Dict[str, Any]] = []
    for node in mapping.values():
        msg = node.get("message")
        if not msg:
            continue
        content = msg.get("content")
        text = extract_text(content)
        if not text:
            continue
        messages.append({
            "role": (msg.get("author") or {}).get("role", "unknown"),
            "time": msg.get("create_time"),
            "text": text,
        })

    messages.sort(key=lambda m: m.get("time") or 0)

    lines: List[str] = []
    for idx, msg in enumerate(messages, 1):
        ts = msg.get("time")
        if ts:
            dt = datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="seconds")
        else:
            dt = "unknown"
        lines.append(f"[{idx:03d}] {msg['role']} | {dt}")
        lines.append(msg["text"])
        lines.append("")

    return "\n".join(lines).strip()


def main() -> int:
    workspace_root = resolve_workspace_root()
    export_path = Path(os.environ.get("MAROON_CHATGPT_EXPORT", workspace_root / "conversations.json"))
    if not export_path.exists():
        print(f"Export not found: {export_path}")
        return 1

    raw_dir = resolve_raw_dir(workspace_root)
    raw_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = raw_dir / "import_manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {}

    data = json.loads(export_path.read_text(encoding="utf-8"))
    total = len(data)
    imported = 0

    for conv in data:
        conv_id = conv.get("conversation_id") or conv.get("id") or ""
        if conv_id in manifest:
            continue

        title = conv.get("title") or "untitled"
        create_time = conv.get("create_time") or conv.get("update_time") or None
        if create_time:
            dt = datetime.fromtimestamp(create_time, tz=timezone.utc)
        else:
            dt = datetime.now(timezone.utc)
        year = dt.strftime("%Y")
        month = dt.strftime("%m")
        date = dt.strftime("%Y-%m-%d")

        folder = raw_dir / year / month
        folder.mkdir(parents=True, exist_ok=True)
        filename = f"{date}__{sanitize(title)}__chatgpt.maroon.md"
        file_path = folder / filename

        thread_text = build_thread_text(conv)
        if not thread_text:
            continue

        metadata = []
        metadata.append("---")
        metadata.append("maroon_version: 1.0")
        metadata.append("phase: phase_0_discovery")
        metadata.append(f"ingested_at: {datetime.now(timezone.utc).isoformat(timespec='seconds')}Z")
        metadata.append("ingest_stage: raw")
        metadata.append("source:")
        metadata.append("  system: chatgpt")
        metadata.append("  channel: export")
        metadata.append("thread:")
        metadata.append(f"  title: \"{title.replace('"', '\\"')}\"")
        metadata.append(f"  confidence: unknown")
        if conv_id:
            metadata.append(f"  conversation_id: {conv_id}")
        metadata.append("content_classification:")
        metadata.append("  possible_types: []")
        metadata.append("  certainty: low")
        metadata.append("tags: []")
        metadata.append("assumptions:")
        metadata.append("  - content preserved verbatim")
        metadata.append("  - no validation performed")
        metadata.append("instructions_to_downstream_ai:")
        metadata.append("  - do not summarize")
        metadata.append("  - do not discard")
        metadata.append("  - reclassify with higher confidence")
        metadata.append("  - surface decisions vs exploration")
        metadata.append("---")
        metadata.append("")
        metadata.append("# Verbatim Thread Content")
        metadata.append("")
        metadata.append("<<<BEGIN THREAD>>>")
        metadata.append(thread_text)
        metadata.append("<<<END THREAD>>>")
        metadata.append("")

        file_path.write_text("\n".join(metadata), encoding="utf-8")
        manifest[conv_id] = str(file_path)
        imported += 1

    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    log_path = raw_dir / "import_log.md"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(f"- {datetime.now(timezone.utc).isoformat(timespec='seconds')}Z imported {imported} of {total} threads from {export_path}\n")

    print(f"Imported: {imported} / {total}")
    print(f"Manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

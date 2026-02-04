from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import os
import re
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Maroon Ingest Engine")


class IngestPayload(BaseModel):
    thread_title: str
    source_system: str
    source_channel: str
    raw_content: str
    tags: List[str] = Field(default_factory=list)
    possible_types: List[str] = Field(default_factory=list)
    confidence: str = "unknown"


def resolve_base_dir() -> Path:
    env = os.environ.get("MAROON_INGEST_DIR")
    if env:
        return Path(env).expanduser().resolve()

    script_dir = Path(__file__).resolve().parent
    core_root = script_dir.parent.parent  # Maroon-Core
    workspace_root = core_root.parent
    return (workspace_root / "maroon_ingest").resolve()


def sanitize(text: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9\-]+", "-", text.lower())
    cleaned = re.sub(r"-+", "-", cleaned).strip("-")
    return cleaned or "untitled"


def yaml_list(items: List[str], indent: int = 0) -> List[str]:
    if not items:
        return [" " * indent + "[]"]
    prefix = " " * indent
    return [f"{prefix}- {i}" for i in items]


def escape_quotes(text: str) -> str:
    return text.replace('"', '\\"')


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ingest")
def ingest(payload: IngestPayload):
    if not payload.raw_content.strip():
        raise HTTPException(status_code=400, detail="raw_content is required")

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat(timespec="seconds").replace("+00:00", "Z")
    year = now.strftime("%Y")
    month = now.strftime("%m")
    date = now.strftime("%Y-%m-%d")

    base_dir = resolve_base_dir()
    folder = base_dir / year / month
    folder.mkdir(parents=True, exist_ok=True)

    filename = f"{date}__{sanitize(payload.thread_title)}__{payload.source_system}.maroon.md"
    file_path = folder / filename

    if file_path.exists():
        suffix = 1
        while True:
            candidate = folder / f"{date}__{sanitize(payload.thread_title)}__{payload.source_system}__{suffix}.maroon.md"
            if not candidate.exists():
                file_path = candidate
                break
            suffix += 1

    metadata = []
    metadata.append("---")
    metadata.append("maroon_version: 1.0")
    metadata.append("phase: phase_0_discovery")
    metadata.append(f"ingested_at: {now_iso}")
    metadata.append("source:")
    metadata.append(f"  system: {payload.source_system}")
    metadata.append(f"  channel: {payload.source_channel}")
    metadata.append("thread:")
    metadata.append(f"  title: \"{escape_quotes(payload.thread_title)}\"")
    metadata.append(f"  confidence: {payload.confidence}")
    metadata.append("content_classification:")
    if payload.possible_types:
        metadata.append("  possible_types:")
        metadata.extend(yaml_list(payload.possible_types, indent=4))
    else:
        metadata.append("  possible_types: []")
    metadata.append("  certainty: low")
    if payload.tags:
        metadata.append("tags:")
        metadata.extend(yaml_list(payload.tags, indent=2))
    else:
        metadata.append("tags: []")
    metadata.append("assumptions:")
    metadata.extend(yaml_list([
        "content preserved verbatim",
        "no validation performed",
    ], indent=2))
    metadata.append("instructions_to_downstream_ai:")
    metadata.extend(yaml_list([
        "do not summarize",
        "do not discard",
        "reclassify with higher confidence",
        "surface decisions vs exploration",
    ], indent=2))
    metadata.append("---")
    metadata.append("")
    metadata.append("# Verbatim Thread Content")
    metadata.append("")
    metadata.append("<<<BEGIN THREAD>>>")
    metadata.append(payload.raw_content)
    metadata.append("<<<END THREAD>>>")
    metadata.append("")

    file_path.write_text("\n".join(metadata), encoding="utf-8")

    return {
        "status": "ingested",
        "file": str(file_path),
        "ingested_at": now_iso,
    }

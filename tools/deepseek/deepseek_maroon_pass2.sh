#!/usr/bin/env bash
set -euo pipefail

# Second-pass rewrite using the aggregated corpus context ("learned" pass).
# Reads an existing run directory produced by deepseek_maroon_cleanup.sh.
# Writes per-file outputs under <run>/<file-dir>/pass2/.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT_DIR="${MAROON_ROOT:-}"
if [[ -z "$ROOT_DIR" ]]; then
  if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
  else
    ROOT_DIR="$(pwd)"
  fi
fi

RUN_DIR="${MAROON_RUN_DIR:-${1:-}}"
if [[ -z "$RUN_DIR" ]]; then
  echo "MAROON_RUN_DIR (or a positional arg) is required." >&2
  exit 2
fi

MODEL="${DEEPSEEK_MODEL:-deepseek-r1:8b}"
BACKEND="${DEEPSEEK_BACKEND:-ollama}"

CHUNK_CHARS="${MAROON_CHUNK_CHARS:-12000}"
FULL_CHARS="${MAROON_FULL_CHARS:-24000}"

# Max chars of global context to include in prompts.
GLOBAL_CTX_CHARS="${MAROON_GLOBAL_CONTEXT_CHARS:-12000}"

NUM_CTX="${DEEPSEEK_NUM_CTX:-0}"
TEMPERATURE="${DEEPSEEK_TEMPERATURE:-0}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found." >&2
  exit 1
fi

if [[ "$BACKEND" == "ollama" ]]; then
  if ! command -v ollama >/dev/null 2>&1; then
    echo "ollama is required but not found in PATH." >&2
    exit 1
  fi
else
  echo "Unsupported DEEPSEEK_BACKEND: $BACKEND" >&2
  exit 1
fi

export MAROON_RUN_DIR="$RUN_DIR"

python3 -u - <<'PY'
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime

run_dir = os.environ.get("MAROON_RUN_DIR")
if not run_dir:
    print("MAROON_RUN_DIR is required", file=sys.stderr)
    sys.exit(2)
run_dir = os.path.abspath(run_dir)

model = os.environ.get("DEEPSEEK_MODEL", "deepseek-r1:8b")
backend = os.environ.get("DEEPSEEK_BACKEND", "ollama")
chunk_chars = int(os.environ.get("MAROON_CHUNK_CHARS", "12000"))
full_chars = int(os.environ.get("MAROON_FULL_CHARS", "24000"))
global_ctx_chars = int(os.environ.get("MAROON_GLOBAL_CONTEXT_CHARS", "12000"))
num_ctx = os.environ.get("DEEPSEEK_NUM_CTX", "0")
temperature = os.environ.get("DEEPSEEK_TEMPERATURE", "0")

corpus_dir = os.path.join(run_dir, "_corpus")
summary_path = os.path.join(corpus_dir, "corpus_summary.md")
map_path = os.path.join(corpus_dir, "corpus_map.md")
gaps_path = os.path.join(corpus_dir, "corpus_gaps.md")
priorities_path = os.path.join(corpus_dir, "corpus_priorities.md")

for p in [summary_path, map_path]:
    if not os.path.isfile(p):
        print(f"Missing corpus context file: {p}. Run aggregation first.", file=sys.stderr)
        sys.exit(1)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read().strip()


summary = read_text(summary_path)
mapping = read_text(map_path)
gaps = read_text(gaps_path) if os.path.isfile(gaps_path) else ""
priorities = read_text(priorities_path) if os.path.isfile(priorities_path) else ""

ctx = f"""GLOBAL CORPUS SUMMARY:\n{summary}\n\nGLOBAL CORPUS MAP:\n{mapping}""".strip()
if gaps:
    ctx += f"\n\nGLOBAL GAPS:\n{gaps}".strip()
if priorities:
    ctx += f"\n\nGLOBAL PRIORITIES:\n{priorities}".strip()

ctx = ctx[:global_ctx_chars]


def run_ollama(prompt: str) -> str:
    env = os.environ.copy()
    if num_ctx and num_ctx != "0":
        env["OLLAMA_NUM_CTX"] = str(num_ctx)
    if temperature and temperature != "0":
        env["OLLAMA_TEMPERATURE"] = str(temperature)
    p = subprocess.run(
        ["ollama", "run", model],
        input=prompt,
        text=True,
        capture_output=True,
        env=env,
    )
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or "ollama run failed")
    return p.stdout.strip()


def parse_tagged(text: str, tag: str):
    pattern = re.compile(rf"<{tag}>(.*?)</{tag}>", re.DOTALL | re.IGNORECASE)
    m = pattern.search(text)
    return m.group(1).strip() if m else None


def split_chunks(text: str, limit: int):
    paras = text.split("\n\n")
    chunks = []
    buf = []
    size = 0
    for para in paras:
        p = para.strip("\n")
        if not p:
            continue
        if size + len(p) + 2 > limit and buf:
            chunks.append("\n\n".join(buf))
            buf = [p]
            size = len(p)
        else:
            buf.append(p)
            size += len(p) + 2
    if buf:
        chunks.append("\n\n".join(buf))
    return chunks


def unified_diff(a_text: str, b_text: str) -> str:
    a_lines = a_text.splitlines(keepends=True)
    b_lines = b_text.splitlines(keepends=True)
    diff = difflib.unified_diff(a_lines, b_lines, fromfile="input.md", tofile="rewrite_pass2.md", n=3)
    return "".join(diff)


STYLE = """
Quality bar:
- Harvard-grade clarity for a non-specialist reader.
- Top-down, infrastructure-first structure (identity/governance -> data -> infra -> services -> apps).
- Make guidance global across industries.
- Replace vendor-specific instructions with provider-agnostic patterns; keep vendor-specific notes only as clearly labeled examples.
- Do not invent facts. If something is missing/unknown, add explicit TODOs and questions.
- Do not use nested bullet lists.
""".strip()


def single_pass(doc: str) -> str:
    prompt = f"""
You are an expert editor and systems architect.
Task: Rewrite this document so it is consistent with the GLOBAL CORPUS CONTEXT.
{STYLE}
Additional requirements:
- Align terminology, naming, and structure to the corpus context.
- If the document conflicts with corpus context, do NOT overwrite facts; instead call it out in <ANALYSIS> and propose a resolution.
Return ONLY the tagged sections below, no extra text.

<ANALYSIS>
Key issues, conflicts with corpus context, missing info, redundancies, weak/ambiguous claims.
</ANALYSIS>

<REWRITE>
Rewritten Markdown.
</REWRITE>

<ACTIONS>
Concise action list.
</ACTIONS>

GLOBAL CORPUS CONTEXT:
{ctx}

DOCUMENT:
{doc}
"""
    return run_ollama(prompt)


def chunk_pass(chunk: str) -> str:
    prompt = f"""
You are an expert editor and systems architect.
Task: Rewrite this document chunk so it is consistent with the GLOBAL CORPUS CONTEXT.
{STYLE}
Return ONLY the tagged sections below, no extra text.

<REWRITE>
Rewritten chunk.
</REWRITE>

<NOTES>
Issues, conflicts with corpus context, missing info, redundancies, weak/ambiguous claims.
</NOTES>

GLOBAL CORPUS CONTEXT:
{ctx}

CHUNK:
{chunk}
"""
    return run_ollama(prompt)


def reduce_notes(notes_blob: str) -> str:
    prompt = f"""
You are an expert editor and systems architect.
Task: Consolidate chunk notes into a single report.
{STYLE}
Return ONLY the tagged sections below, no extra text.

<ANALYSIS>
Consolidated issues and conflicts with corpus context.
</ANALYSIS>

<ACTIONS>
Concise action list.
</ACTIONS>

NOTES:
{notes_blob}
"""
    return run_ollama(prompt)


# File dirs are the direct children of run_dir that are not underscore-prefixed.
file_dirs = []
for name in sorted(os.listdir(run_dir)):
    p = os.path.join(run_dir, name)
    if os.path.isdir(p) and not name.startswith("_"):
        file_dirs.append(p)

if not file_dirs:
    print("No file output dirs found in run.")
    sys.exit(1)

pass2_manifest = {
    "run_dir": run_dir,
    "model": model,
    "backend": backend,
    "global_context_files": {
        "corpus_summary": summary_path,
        "corpus_map": map_path,
        "corpus_gaps": gaps_path if os.path.isfile(gaps_path) else None,
        "corpus_priorities": priorities_path if os.path.isfile(priorities_path) else None,
    },
    "global_context_chars": global_ctx_chars,
    "started_at": datetime.now().isoformat(timespec="seconds"),
    "files": [],
    "errors": [],
}

for idx, d in enumerate(file_dirs, 1):
    ip = os.path.join(d, "input_path.txt")
    in_md = os.path.join(d, "input.md")

    entry = {
        "dir": d,
        "input_path": read_text(ip) if os.path.isfile(ip) else None,
        "status": "pending",
        "error": None,
    }

    try:
        if not os.path.isfile(in_md):
            raise RuntimeError("missing input.md")

        doc = read_text(in_md)
        out_dir = os.path.join(d, "pass2")
        os.makedirs(out_dir, exist_ok=True)

        rewrite_text = None
        analysis_text = None
        actions_text = None

        if len(doc) <= full_chars:
            resp = single_pass(doc)
            write_text = lambda p, c: open(p, "w", encoding="utf-8").write(c)
            write_text(os.path.join(out_dir, "full_response.txt"), resp + "\n")
            analysis_text = parse_tagged(resp, "ANALYSIS")
            rewrite_text = parse_tagged(resp, "REWRITE")
            actions_text = parse_tagged(resp, "ACTIONS")
        else:
            chunks = split_chunks(doc, chunk_chars)
            notes = []
            rewrites = []
            write_text = lambda p, c: open(p, "w", encoding="utf-8").write(c)
            for cidx, chunk in enumerate(chunks, 1):
                print(f"[pass2 {idx}/{len(file_dirs)}] chunk {cidx}/{len(chunks)}")
                resp = chunk_pass(chunk)
                write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_response.txt"), resp + "\n")
                r = parse_tagged(resp, "REWRITE")
                n = parse_tagged(resp, "NOTES")
                if r:
                    rewrites.append(r)
                    write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_rewrite.md"), r + "\n")
                if n:
                    notes.append(n)
                    write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_notes.md"), n + "\n")

            if rewrites:
                rewrite_text = "\n\n".join(rewrites)
            if notes:
                notes_blob = "\n\n".join(notes)
                aresp = reduce_notes(notes_blob)
                write_text(os.path.join(out_dir, "analysis_response.txt"), aresp + "\n")
                analysis_text = parse_tagged(aresp, "ANALYSIS")
                actions_text = parse_tagged(aresp, "ACTIONS")

        if analysis_text:
            open(os.path.join(out_dir, "analysis.md"), "w", encoding="utf-8").write(analysis_text + "\n")
        if actions_text:
            open(os.path.join(out_dir, "actions.md"), "w", encoding="utf-8").write(actions_text + "\n")
        if rewrite_text:
            rewrite_out = rewrite_text + ("\n" if not rewrite_text.endswith("\n") else "")
            open(os.path.join(out_dir, "rewrite.md"), "w", encoding="utf-8").write(rewrite_out)

            diff = unified_diff(doc, rewrite_out)
            if diff.strip():
                open(os.path.join(out_dir, "diff.patch"), "w", encoding="utf-8").write(diff)

        entry["status"] = "ok"

    except Exception as e:
        entry["status"] = "error"
        entry["error"] = str(e)
        pass2_manifest["errors"].append({"dir": d, "error": entry["error"]})

    pass2_manifest["files"].append(entry)

pass2_manifest["finished_at"] = datetime.now().isoformat(timespec="seconds")
with open(os.path.join(run_dir, "run_manifest_pass2.json"), "w", encoding="utf-8") as f:
    f.write(json.dumps(pass2_manifest, indent=2) + "\n")

if pass2_manifest["errors"]:
    print(f"Pass2 completed with {len(pass2_manifest['errors'])} error(s).")
    sys.exit(1)

print("Pass2 done.")
PY

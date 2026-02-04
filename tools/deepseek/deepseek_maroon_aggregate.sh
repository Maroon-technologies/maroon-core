#!/usr/bin/env bash
set -euo pipefail

# Aggregate DeepSeek per-file outputs into a single corpus synthesis.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT_DIR="${MAROON_ROOT:-}"
if [[ -z "$ROOT_DIR" ]]; then
  if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
  else
    ROOT_DIR="$(pwd)"
  fi
fi
OUTPUT_ROOT="${MAROON_OUTPUT_DIR:-$ROOT_DIR/deepseek_outputs}"
RUN_DIR="${MAROON_RUN_DIR:-}"  # optional explicit run directory
MODEL="${DEEPSEEK_MODEL:-deepseek-r1:8b}"
BACKEND="${DEEPSEEK_BACKEND:-ollama}"
CHUNK_CHARS="${MAROON_AGG_CHUNK_CHARS:-12000}"
FULL_CHARS="${MAROON_AGG_FULL_CHARS:-24000}"
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

python3 -u - <<'PY'
import os
import re
import sys
import time
import subprocess
from pathlib import Path

root_dir = os.environ.get("MAROON_ROOT", os.getcwd())
output_root = os.environ.get("MAROON_OUTPUT_DIR", os.path.join(root_dir, "deepseek_outputs"))
run_dir = os.environ.get("MAROON_RUN_DIR", "").strip()
model = os.environ.get("DEEPSEEK_MODEL", "deepseek-r1:8b")
backend = os.environ.get("DEEPSEEK_BACKEND", "ollama")
chunk_chars = int(os.environ.get("MAROON_AGG_CHUNK_CHARS", "12000"))
full_chars = int(os.environ.get("MAROON_AGG_FULL_CHARS", "24000"))
num_ctx = os.environ.get("DEEPSEEK_NUM_CTX", "0")
temperature = os.environ.get("DEEPSEEK_TEMPERATURE", "0")

if not run_dir:
    # pick latest run folder
    if not os.path.isdir(output_root):
        print("No deepseek_outputs folder found.")
        sys.exit(1)
    runs = [d for d in os.listdir(output_root) if os.path.isdir(os.path.join(output_root, d))]
    if not runs:
        print("No run folders found under deepseek_outputs.")
        sys.exit(1)
    run_dir = os.path.join(output_root, sorted(runs)[-1])
else:
    run_dir = os.path.abspath(run_dir)

if not os.path.isdir(run_dir):
    print(f"Run directory not found: {run_dir}")
    sys.exit(1)


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


def parse_tagged(text: str, tag: str):
    pattern = re.compile(rf"<{tag}>(.*?)</{tag}>", re.DOTALL | re.IGNORECASE)
    m = pattern.search(text)
    return m.group(1).strip() if m else None


entries = []

# One entry per file directory. Prefer pass2 outputs if present.
for name in sorted(os.listdir(run_dir)):
    file_dir = os.path.join(run_dir, name)
    if not os.path.isdir(file_dir):
        continue
    if name.startswith("_"):
        continue

    input_path = None
    ip = os.path.join(file_dir, "input_path.txt")
    if os.path.isfile(ip):
        with open(ip, "r", encoding="utf-8", errors="ignore") as f:
            input_path = f.read().strip()

    chosen_pass = None
    analysis = None
    actions = None

    candidates = [
        ("pass2", os.path.join(file_dir, "pass2", "analysis.md"), os.path.join(file_dir, "pass2", "actions.md")),
        ("pass1", os.path.join(file_dir, "analysis.md"), os.path.join(file_dir, "actions.md")),
    ]

    for pass_name, ap, acp in candidates:
        a = None
        c = None
        if os.path.isfile(ap):
            with open(ap, "r", encoding="utf-8", errors="ignore") as f:
                a = f.read().strip()
        if os.path.isfile(acp):
            with open(acp, "r", encoding="utf-8", errors="ignore") as f:
                c = f.read().strip()
        if a or c:
            chosen_pass = pass_name
            analysis = a
            actions = c
            break

    if not (analysis or actions):
        continue

    block = []
    if input_path:
        block.append(f"FILE: {input_path}")
    if chosen_pass:
        block.append(f"PASS: {chosen_pass}")
    if analysis:
        block.append("ANALYSIS:\n" + analysis)
    if actions:
        block.append("ACTIONS:\n" + actions)
    entries.append("\n".join(block))

if not entries:
    print("No analysis/actions files found in run.")
    sys.exit(1)

corpus = "\n\n---\n\n".join(entries)

out_dir = os.path.join(run_dir, "_corpus")
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "corpus_notes.txt"), "w", encoding="utf-8") as f:
    f.write(corpus + "\n")


def single_pass(notes: str):
    prompt = f"""
You are an expert editor and systems architect.
Task: Produce a global synthesis from corpus notes.
Rules:
- Do not invent facts.
- Use Harvard-grade clarity for a non-specialist reader.
- Make the synthesis global across industries.
- Use a top-down, infrastructure-first framing (identity/governance -> data -> infra -> services -> apps).
- Replace vendor-specific assumptions with provider-agnostic patterns; keep vendor-specific notes only as clearly labeled examples.
- If information is missing/unknown, add explicit TODOs and questions (do not guess).
- Do not use nested bullet lists.
Return ONLY the tagged sections below, no extra text.

<GLOBAL_SUMMARY>
A coherent, executive-grade synthesis that unifies identity, product value, systems, infrastructure, data collection, and inter-business flows.
</GLOBAL_SUMMARY>

<MAP>
A clear, concise map of businesses, systems, and how they connect.
</MAP>

<GAPS>
Cross-cutting missing information, contradictions, redundancies, weak or ambiguous claims, and data gaps.
</GAPS>

<PRIORITIES>
A concise, ordered action list.
</PRIORITIES>

NOTES:
{notes}
"""
    return run_ollama(prompt)


def chunk_pass(chunk: str):
    prompt = f"""
You are an expert editor and systems architect.
Summarize this corpus-notes chunk.
Rules:
- Do not invent facts.
- Make guidance global across industries.
- Use a top-down, infrastructure-first framing (identity/governance -> data -> infra -> services -> apps).
- Replace vendor-specific assumptions with provider-agnostic patterns; keep vendor-specific notes only as clearly labeled examples.
- If information is missing/unknown, add explicit TODOs and questions (do not guess).
- Do not use nested bullet lists.
Return ONLY the tagged sections below, no extra text.

<SUMMARY>
Key points and systems.
</SUMMARY>

<GAPS>
Missing info, contradictions, redundancies, weak or ambiguous claims, and data gaps.
</GAPS>

<PRIORITIES>
Concise action list.
</PRIORITIES>

CHUNK:
{chunk}
"""
    return run_ollama(prompt)


if len(corpus) <= full_chars:
    response = single_pass(corpus)
    with open(os.path.join(out_dir, "corpus_response.txt"), "w", encoding="utf-8") as f:
        f.write(response + "\n")
    summary = parse_tagged(response, "GLOBAL_SUMMARY")
    mapping = parse_tagged(response, "MAP")
    gaps = parse_tagged(response, "GAPS")
    priorities = parse_tagged(response, "PRIORITIES")
    if summary:
        with open(os.path.join(out_dir, "corpus_summary.md"), "w", encoding="utf-8") as f:
            f.write(summary + "\n")
    if mapping:
        with open(os.path.join(out_dir, "corpus_map.md"), "w", encoding="utf-8") as f:
            f.write(mapping + "\n")
    if gaps:
        with open(os.path.join(out_dir, "corpus_gaps.md"), "w", encoding="utf-8") as f:
            f.write(gaps + "\n")
    if priorities:
        with open(os.path.join(out_dir, "corpus_priorities.md"), "w", encoding="utf-8") as f:
            f.write(priorities + "\n")
else:
    chunks = split_chunks(corpus, chunk_chars)
    summaries = []
    gaps_all = []
    priorities_all = []
    for idx, chunk in enumerate(chunks, 1):
        resp = chunk_pass(chunk)
        with open(os.path.join(out_dir, f"chunk_{idx:03d}_response.txt"), "w", encoding="utf-8") as f:
            f.write(resp + "\n")
        s = parse_tagged(resp, "SUMMARY")
        g = parse_tagged(resp, "GAPS")
        p = parse_tagged(resp, "PRIORITIES")
        if s:
            summaries.append(s)
        if g:
            gaps_all.append(g)
        if p:
            priorities_all.append(p)

    combined = "\n\n".join(summaries + gaps_all + priorities_all)
    final_resp = single_pass(combined)
    with open(os.path.join(out_dir, "corpus_response.txt"), "w", encoding="utf-8") as f:
        f.write(final_resp + "\n")
    summary = parse_tagged(final_resp, "GLOBAL_SUMMARY")
    mapping = parse_tagged(final_resp, "MAP")
    gaps = parse_tagged(final_resp, "GAPS")
    priorities = parse_tagged(final_resp, "PRIORITIES")
    if summary:
        with open(os.path.join(out_dir, "corpus_summary.md"), "w", encoding="utf-8") as f:
            f.write(summary + "\n")
    if mapping:
        with open(os.path.join(out_dir, "corpus_map.md"), "w", encoding="utf-8") as f:
            f.write(mapping + "\n")
    if gaps:
        with open(os.path.join(out_dir, "corpus_gaps.md"), "w", encoding="utf-8") as f:
            f.write(gaps + "\n")
    if priorities:
        with open(os.path.join(out_dir, "corpus_priorities.md"), "w", encoding="utf-8") as f:
            f.write(priorities + "\n")

print(f"Corpus synthesis written to: {out_dir}")
PY

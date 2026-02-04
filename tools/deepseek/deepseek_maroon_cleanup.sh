#!/usr/bin/env bash
set -euo pipefail

# DeepSeek corpus cleanup runner.
# - Reads source Markdown files (never edits in place).
# - Writes per-file: input copy, analysis, rewrite, actions, diff.
# - Writes run-level: run_manifest.json, and then runs the corpus aggregator.

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
RUN_TS="${MAROON_RUN_TS:-$(date '+%Y%m%d-%H%M%S')}"
RUN_DIR="${MAROON_RUN_DIR:-$OUTPUT_ROOT/$RUN_TS}"
RUNS_DIR="${MAROON_RUNS_DIR:-$ROOT_DIR/runs}"

# Comma-separated, filename-based globs (lowercased internally).
# Default intentionally targets Maroon + patents + schemas + systems + business + truth teller.
GLOBS="${MAROON_GLOBS:-${MAROON_GLOB:-*maroon*.md,*patent*.md,*schema*.md,*business*.md,*system*.md,*ontology*.md,*spec*.md,*truth*.md,*nanny*.md}}"

SINCE_HOURS="${MAROON_SINCE_HOURS:-0}"
MAX_FILES="${MAROON_MAX_FILES:-0}"

MODEL="${DEEPSEEK_MODEL:-deepseek-r1:8b}"
BACKEND="${DEEPSEEK_BACKEND:-ollama}"

CHUNK_CHARS="${MAROON_CHUNK_CHARS:-12000}"
FULL_CHARS="${MAROON_FULL_CHARS:-24000}"

# Optional path filters (regex on relpath):
# - If INCLUDE is set, only matching paths are processed.
# - If EXCLUDE is set, matching paths are skipped.
INCLUDE_PATH_RE="${MAROON_INCLUDE_PATH_RE:-}"
EXCLUDE_PATH_RE="${MAROON_EXCLUDE_PATH_RE:-}"

DRY_RUN="${MAROON_DRY_RUN:-0}"

# If set to 1, skip aggregation.
NO_AGGREGATE="${MAROON_NO_AGGREGATE:-0}"

# If set to 1, run a second rewrite pass using the aggregated corpus context,
# then re-aggregate (the aggregator prefers pass2 outputs when present).
SECOND_PASS="${MAROON_SECOND_PASS:-0}"

# If set to 1, skip files that have not changed since the last run (redundancy guard).
SKIP_UNCHANGED="${MAROON_SKIP_UNCHANGED:-1}"

# If set to 1, copy small aggregated artifacts into ./runs/<timestamp>/ for git tracking.
COPY_TO_RUNS="${MAROON_COPY_TO_RUNS:-1}"

# If set to 1, attempt to auto-commit ./runs after a successful run (requires a git repo rooted at $ROOT_DIR).
GIT_AUTOCOMMIT="${MAROON_GIT_AUTOCOMMIT:-0}"

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

if [[ "$DRY_RUN" == "1" ]]; then
  NO_AGGREGATE=1
  SECOND_PASS=0
  COPY_TO_RUNS=0
  GIT_AUTOCOMMIT=0
fi

export MAROON_RUN_TS
export MAROON_RUN_DIR="$RUN_DIR"

python3 -u - <<'PY'
import difflib
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime

root_dir = os.environ.get("MAROON_ROOT", os.getcwd())
output_root = os.environ.get("MAROON_OUTPUT_DIR", os.path.join(root_dir, "deepseek_outputs"))
run_ts = os.environ.get("MAROON_RUN_TS") or datetime.now().strftime("%Y%m%d-%H%M%S")
run_dir = os.environ.get("MAROON_RUN_DIR") or os.path.join(output_root, run_ts)

globs_raw = os.environ.get("MAROON_GLOBS") or os.environ.get("MAROON_GLOB") or "*maroon*.md"
glob_list = [g.strip().lower() for g in globs_raw.split(",") if g.strip()]

since_hours = float(os.environ.get("MAROON_SINCE_HOURS", "0"))
max_files = int(os.environ.get("MAROON_MAX_FILES", "0"))

model = os.environ.get("DEEPSEEK_MODEL", "deepseek-r1:8b")
backend = os.environ.get("DEEPSEEK_BACKEND", "ollama")

chunk_chars = int(os.environ.get("MAROON_CHUNK_CHARS", "12000"))
full_chars = int(os.environ.get("MAROON_FULL_CHARS", "24000"))

dry_run = os.environ.get("MAROON_DRY_RUN", "0") == "1"
skip_unchanged = os.environ.get("MAROON_SKIP_UNCHANGED", "1") == "1"

include_path_re = os.environ.get("MAROON_INCLUDE_PATH_RE", "").strip()
exclude_path_re = os.environ.get("MAROON_EXCLUDE_PATH_RE", "").strip()

num_ctx = os.environ.get("DEEPSEEK_NUM_CTX", "0")
temperature = os.environ.get("DEEPSEEK_TEMPERATURE", "0")

now = time.time()
cutoff = now - (since_hours * 3600)

prune_dirs = {
    ".git",
    "node_modules",
    ".venv",
    "venv",
    "dist",
    "build",
    "target",
    "__pycache__",
    ".pytest_cache",
    ".cache",
    ".idea",
    ".vscode",
    "deepseek_outputs",
    "runs",
}


def should_prune(dir_name: str) -> bool:
    return dir_name in prune_dirs


def iter_files():
    count = 0
    include_rx = re.compile(include_path_re, re.IGNORECASE) if include_path_re else None
    exclude_rx = re.compile(exclude_path_re, re.IGNORECASE) if exclude_path_re else None

    for cur_root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if not should_prune(d)]

        for fname in files:
            lf = fname.lower()
            if not lf.endswith(".md"):
                continue

            if not any(fnmatch.fnmatch(lf, g) for g in glob_list):
                continue

            path = os.path.join(cur_root, fname)
            try:
                st = os.stat(path)
            except OSError:
                continue

            if since_hours > 0 and st.st_mtime < cutoff:
                continue

            rel = os.path.relpath(path, root_dir)
            if exclude_rx and exclude_rx.search(rel):
                continue
            if include_rx and not include_rx.search(rel):
                continue

            yield path
            count += 1
            if max_files and count >= max_files:
                return


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
    # Split by paragraphs, then pack into chunks.
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


def safe_dirname(path: str) -> str:
    rel = os.path.relpath(path, root_dir)
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", rel)
    digest = hashlib.sha1(rel.encode("utf-8")).hexdigest()[:10]
    return f"{safe}__{digest}"


def parse_tagged(text: str, tag: str):
    pattern = re.compile(rf"<{tag}>(.*?)</{tag}>", re.DOTALL | re.IGNORECASE)
    m = pattern.search(text)
    return m.group(1).strip() if m else None


def write_text(path: str, content: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


STYLE = """
Quality bar:
- Harvard-grade clarity for a non-specialist reader.
- Audience: founder with a third-grade education. Use plain language, short sentences, define terms.
- Top-down, infrastructure-first structure (identity/governance -> data -> infra -> services -> apps).
- Make guidance global across industries.
- Replace vendor-specific instructions with provider-agnostic patterns; keep vendor-specific notes only as clearly labeled examples.
- Assume the source is incomplete. If something is missing/unknown, add explicit TODOs and questions.
- Do not invent facts.
- Keep originals intact; do not request destructive changes.
- Do not use nested bullet lists.
""".strip()


def single_pass(content: str):
    prompt = f"""
You are an expert editor and systems architect.
Task: Analyze a Markdown file and produce a rigorous rewrite.
{STYLE}
Return ONLY the tagged sections below, no extra text.

<ANALYSIS>
List missing information, contradictions, redundancies, weak or ambiguous claims, scope gaps, and data gaps.
</ANALYSIS>

<REWRITE>
Provide the rewritten Markdown.
</REWRITE>

<ACTIONS>
Provide a concise action list of fixes or research needed.
</ACTIONS>

FILE CONTENT:
{content}
"""
    return run_ollama(prompt)


def chunk_rewrite(chunk: str):
    prompt = f"""
You are an expert editor and systems architect.
Task: Rewrite the following Markdown chunk.
{STYLE}
Return ONLY the tagged sections below, no extra text.

<REWRITE>
Rewritten chunk.
</REWRITE>

<NOTES>
Missing info, contradictions, redundancies, unclear claims, and scope gaps in this chunk.
</NOTES>

CHUNK:
{chunk}
"""
    return run_ollama(prompt)


def chunk_analysis(notes_blob: str):
    prompt = f"""
You are an expert editor and systems architect.
Task: Given the combined notes from all chunks, produce a clean final report.
{STYLE}
Return ONLY the tagged sections below, no extra text.

<ANALYSIS>
Consolidated missing info, contradictions, redundancies, weak or ambiguous claims, scope gaps, and data gaps.
</ANALYSIS>

<ACTIONS>
Concise action list of fixes or research needed.
</ACTIONS>

NOTES:
{notes_blob}
"""
    return run_ollama(prompt)


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def unified_diff(a_text: str, b_text: str) -> str:
    a_lines = a_text.splitlines(keepends=True)
    b_lines = b_text.splitlines(keepends=True)
    diff = difflib.unified_diff(
        a_lines,
        b_lines,
        fromfile="input.md",
        tofile="rewrite.md",
        n=3,
    )
    return "".join(diff)


def main() -> int:
    files = list(iter_files())

    # Equal priority ordering (deterministic by path)
    files.sort(key=lambda p: os.path.relpath(p, root_dir).lower())
    if dry_run:
        print("DRY RUN: matched files")
        for p in files:
            print(p)
        return 0

    if not files:
        print("No files matched.")
        return 0

    os.makedirs(run_dir, exist_ok=True)

    cache_path = os.path.join(output_root, ".file_cache.json")
    cache = {}
    if skip_unchanged and os.path.isfile(cache_path):
        try:
            cache = json.load(open(cache_path, "r", encoding="utf-8"))
        except Exception:
            cache = {}

    manifest = {
        "run_ts": run_ts,
        "run_dir": os.path.abspath(run_dir),
        "root_dir": os.path.abspath(root_dir),
        "model": model,
        "backend": backend,
        "globs": glob_list,
        "since_hours": since_hours,
        "chunk_chars": chunk_chars,
        "full_chars": full_chars,
        "include_path_re": include_path_re or None,
        "exclude_path_re": exclude_path_re or None,
        "skip_unchanged": skip_unchanged,
        "started_at": datetime.now().isoformat(timespec="seconds"),
        "files": [],
        "errors": [],
    }

    for idx, path in enumerate(files, 1):
        rel = os.path.relpath(path, root_dir)
        print(f"[{idx}/{len(files)}] {rel}")

        entry = {
            "path": os.path.abspath(path),
            "relpath": rel,
            "out_dir": None,
            "status": "pending",
            "error": None,
            "input_sha256": None,
            "rewrite_sha256": None,
        }

        try:
            st = os.stat(path)
            raw = open(path, "rb").read()
            entry["input_sha256"] = sha256_bytes(raw)

            content = raw.decode("utf-8", errors="replace")

            out_dir = os.path.join(run_dir, safe_dirname(path))
            entry["out_dir"] = os.path.abspath(out_dir)
            os.makedirs(out_dir, exist_ok=True)

            write_text(os.path.join(out_dir, "input_path.txt"), entry["path"] + "\n")
            write_text(os.path.join(out_dir, "input_stat.json"), json.dumps({
                "size": st.st_size,
                "mtime": st.st_mtime,
                "input_sha256": entry["input_sha256"],
            }, indent=2) + "\n")
            write_text(os.path.join(out_dir, "settings.json"), json.dumps({
                "model": model,
                "backend": backend,
                "globs": glob_list,
                "since_hours": since_hours,
                "chunk_chars": chunk_chars,
                "full_chars": full_chars,
                "run_ts": run_ts,
                "include_path_re": include_path_re or None,
                "exclude_path_re": exclude_path_re or None,
            }, indent=2) + "\n")

            # Always keep an input copy for forensics/repro.
            write_text(os.path.join(out_dir, "input.md"), content + ("\n" if not content.endswith("\n") else ""))

            # Redundancy guard: skip unchanged files
            if skip_unchanged:
                cached = cache.get(entry["path"])
                if cached == entry["input_sha256"]:
                    entry["status"] = "skipped"
                    manifest["files"].append(entry)
                    continue

            rewrite_text = None
            analysis_text = None
            actions_text = None

            if len(content) <= full_chars:
                response = single_pass(content)
                analysis_text = parse_tagged(response, "ANALYSIS")
                rewrite_text = parse_tagged(response, "REWRITE")
                actions_text = parse_tagged(response, "ACTIONS")
                write_text(os.path.join(out_dir, "full_response.txt"), response + "\n")
            else:
                chunks = split_chunks(content, chunk_chars)
                all_notes = []
                rewrites = []
                for cidx, chunk in enumerate(chunks, 1):
                    print(f"  - chunk {cidx}/{len(chunks)}")
                    resp = chunk_rewrite(chunk)
                    write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_response.txt"), resp + "\n")
                    r = parse_tagged(resp, "REWRITE")
                    n = parse_tagged(resp, "NOTES")
                    if r:
                        rewrites.append(r)
                        write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_rewrite.md"), r + "\n")
                    if n:
                        all_notes.append(n)
                        write_text(os.path.join(out_dir, f"chunk_{cidx:03d}_notes.md"), n + "\n")

                if rewrites:
                    rewrite_text = "\n\n".join(rewrites)

                if all_notes:
                    notes_blob = "\n\n".join(all_notes)
                    analysis_resp = chunk_analysis(notes_blob)
                    write_text(os.path.join(out_dir, "analysis_response.txt"), analysis_resp + "\n")
                    analysis_text = parse_tagged(analysis_resp, "ANALYSIS")
                    actions_text = parse_tagged(analysis_resp, "ACTIONS")

            if analysis_text:
                write_text(os.path.join(out_dir, "analysis.md"), analysis_text + "\n")
            if actions_text:
                write_text(os.path.join(out_dir, "actions.md"), actions_text + "\n")

            if rewrite_text:
                # Always end with newline for stable diffs.
                rewrite_out = rewrite_text + ("\n" if not rewrite_text.endswith("\n") else "")
                write_text(os.path.join(out_dir, "rewrite.md"), rewrite_out)
                entry["rewrite_sha256"] = sha256_bytes(rewrite_out.encode("utf-8"))

                diff = unified_diff(content, rewrite_out)
                if diff.strip():
                    write_text(os.path.join(out_dir, "diff.patch"), diff)

            entry["status"] = "ok"
            if skip_unchanged:
                cache[entry["path"]] = entry["input_sha256"]

        except Exception as e:
            entry["status"] = "error"
            entry["error"] = str(e)
            manifest["errors"].append({
                "path": entry["path"],
                "error": entry["error"],
            })

        manifest["files"].append(entry)

    manifest["finished_at"] = datetime.now().isoformat(timespec="seconds")
    manifest_path = os.path.join(run_dir, "run_manifest.json")
    write_text(manifest_path, json.dumps(manifest, indent=2) + "\n")

    # Human-friendly pointer to latest run.
    os.makedirs(output_root, exist_ok=True)
    write_text(os.path.join(output_root, "LATEST"), run_ts + "\n")

    # Update cache
    if skip_unchanged:
        try:
            write_text(cache_path, json.dumps(cache, indent=2) + "\n")
        except Exception:
            pass

    if manifest["errors"]:
        print(f"Completed with {len(manifest['errors'])} error(s). See {manifest_path}")
        return 1

    print("Done.")
    print(f"RUN_DIR={os.path.abspath(run_dir)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

# Auto-aggregate after cleanup.
if [[ "$NO_AGGREGATE" != "1" ]]; then
  if [[ -x "$SCRIPT_DIR/deepseek_maroon_aggregate.sh" ]]; then
    MAROON_RUN_DIR="$RUN_DIR" "$SCRIPT_DIR/deepseek_maroon_aggregate.sh" || true
  fi

  if [[ "$SECOND_PASS" == "1" ]]; then
    if [[ -x "$SCRIPT_DIR/deepseek_maroon_pass2.sh" ]]; then
      MAROON_RUN_DIR="$RUN_DIR" "$SCRIPT_DIR/deepseek_maroon_pass2.sh" || true
      # Re-aggregate using pass2 outputs (if any were produced).
      if [[ -x "$SCRIPT_DIR/deepseek_maroon_aggregate.sh" ]]; then
        MAROON_RUN_DIR="$RUN_DIR" "$SCRIPT_DIR/deepseek_maroon_aggregate.sh" || true
      fi
    fi
  fi

  if [[ "$COPY_TO_RUNS" == "1" ]]; then
    mkdir -p "$RUNS_DIR/$RUN_TS"
    if [[ -d "$RUN_DIR/_corpus" ]]; then
      cp "$RUN_DIR/_corpus/"*.md "$RUNS_DIR/$RUN_TS/" 2>/dev/null || true
      cp "$RUN_DIR/_corpus/"*.txt "$RUNS_DIR/$RUN_TS/" 2>/dev/null || true
    fi
    cp "$RUN_DIR/run_manifest.json" "$RUNS_DIR/$RUN_TS/" 2>/dev/null || true
    printf "%s\n" "$RUN_TS" > "$RUNS_DIR/LATEST"
  fi

  if [[ "$GIT_AUTOCOMMIT" == "1" ]]; then
    if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -C "$ROOT_DIR" add -A "$RUNS_DIR" deepseek_maroon_cleanup.sh deepseek_maroon_aggregate.sh >/dev/null 2>&1 || true
      git -C "$ROOT_DIR" commit -m "DeepSeek run $RUN_TS" >/dev/null 2>&1 || true
    fi
  fi
fi

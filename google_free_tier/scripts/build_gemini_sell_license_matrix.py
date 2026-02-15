#!/usr/bin/env python3
"""Build a Gemini-backed sell/license/keep valuation matrix from system registry."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def date_tag() -> str:
    return datetime.now(UTC).strftime("%Y_%m_%d")


def as_int(value: Any, fallback: int = 0) -> int:
    try:
        return int(float(str(value)))
    except Exception:
        return fallback


def clean_text(value: Any) -> str:
    return str(value or "").strip()


def fallback_decision(action: str) -> str:
    action = clean_text(action).upper()
    if action == "LICENSE_MODULE":
        return "license"
    if action == "SERVICE_LAYER":
        return "sell"
    return "keep"


def call_gemini(prompt_script: Path, prompt: str, model: str) -> tuple[dict[str, Any], str]:
    cmd = [str(prompt_script), "gemini", prompt, model]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        return {}, f"gemini_call_failed:{proc.stderr.strip() or proc.stdout.strip()}"

    try:
        payload = json.loads(proc.stdout)
    except Exception:
        return {}, "gemini_invalid_response_json"

    text = ""
    for cand in payload.get("candidates", []):
        for part in ((cand.get("content") or {}).get("parts") or []):
            if part.get("text"):
                text += str(part["text"]) + "\n"
    text = text.strip()
    if not text:
        return {}, "gemini_empty_text"

    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        return {}, "gemini_no_json_object"

    raw_json = match.group(0)
    try:
        parsed = json.loads(raw_json)
    except Exception:
        return {}, "gemini_json_parse_error"
    return parsed, ""


def build_prompt(row: dict[str, str]) -> str:
    payload = {
        "system_id": row.get("system_id", ""),
        "name": row.get("name", ""),
        "pillar_id": row.get("pillar_id", ""),
        "readiness_stage": row.get("readiness_stage", ""),
        "strategic_score": row.get("strategic_score", ""),
        "value_band_usd": row.get("value_band_usd", ""),
        "recommended_commercial_action": row.get("recommended_commercial_action", ""),
        "monetization_path": row.get("monetization_path", ""),
        "signals": row.get("signals", ""),
    }
    return (
        "You are a conservative commercialization analyst. "
        "Given the system JSON, return ONLY one compact JSON object with keys: "
        "decision (sell|license|keep), rationale, value_low_usd, value_high_usd, confidence_0_1. "
        "Keep rationale under 18 words. Do not add markdown.\n\n"
        f"SYSTEM_JSON={json.dumps(payload, separators=(',', ':'))}"
    )


def main() -> int:
    gft_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gft-root", default=str(gft_default))
    parser.add_argument("--top-n", type=int, default=12)
    parser.add_argument("--model", default="gemini-2.5-flash")
    args = parser.parse_args()

    gft_root = Path(args.gft_root).expanduser().resolve()
    ops_dir = gft_root / "workspace" / "Maroon" / "Reports" / "Ops"
    strategy_dir = gft_root / "workspace" / "Maroon" / "Reports" / "Strategy"
    prompt_script = gft_root / "scripts" / "prompt_model_cli.sh"
    registry_csv = ops_dir / "maroon_complete_picture_system_registry_latest.csv"
    if not registry_csv.exists():
        raise FileNotFoundError(f"Missing registry CSV: {registry_csv}")
    if not prompt_script.exists():
        raise FileNotFoundError(f"Missing prompt script: {prompt_script}")

    rows: list[dict[str, str]] = []
    with registry_csv.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            row["_strategic_score"] = str(as_int(row.get("strategic_score", 0), 0))
            rows.append(row)
    rows.sort(key=lambda row: as_int(row.get("_strategic_score", 0), 0), reverse=True)
    selected = rows[: max(1, args.top_n)]

    matrix_rows: list[dict[str, Any]] = []
    for row in selected:
        prompt = build_prompt(row)
        model_out, err = call_gemini(prompt_script=prompt_script, prompt=prompt, model=args.model)
        decision = clean_text(model_out.get("decision", "")).lower()
        if decision not in {"sell", "license", "keep"}:
            decision = fallback_decision(row.get("recommended_commercial_action", ""))

        value_low = as_int(model_out.get("value_low_usd", 0), 0)
        value_high = as_int(model_out.get("value_high_usd", 0), 0)
        if value_high <= 0 or value_high < value_low:
            band = clean_text(row.get("value_band_usd", ""))
            nums = [as_int(n.replace("M", "000000").replace("K", "000"), 0) for n in re.findall(r"[\d.]+[MK]?", band.replace("$", ""))]
            if len(nums) >= 2:
                value_low, value_high = nums[0], nums[1]
            elif len(nums) == 1:
                value_low, value_high = nums[0], nums[0]

        matrix_rows.append(
            {
                "system_id": row.get("system_id", ""),
                "name": row.get("name", ""),
                "pillar_id": row.get("pillar_id", ""),
                "decision": decision,
                "rationale": clean_text(model_out.get("rationale", "")) or "Evidence incomplete; follow current commercial action.",
                "value_low_usd": value_low,
                "value_high_usd": value_high,
                "confidence_0_1": clean_text(model_out.get("confidence_0_1", "")) or "0.45",
                "source_action": row.get("recommended_commercial_action", ""),
                "readiness_stage": row.get("readiness_stage", ""),
                "error": err,
            }
        )

    generated_at = utc_now()
    tag = date_tag()
    summary = {
        "generated_at": generated_at,
        "model": args.model,
        "systems_considered": len(selected),
        "decision_counts": {
            "sell": sum(1 for row in matrix_rows if row["decision"] == "sell"),
            "license": sum(1 for row in matrix_rows if row["decision"] == "license"),
            "keep": sum(1 for row in matrix_rows if row["decision"] == "keep"),
        },
        "rows": matrix_rows,
    }

    json_path = strategy_dir / f"gemini_sell_license_valuation_{tag}.json"
    json_latest = strategy_dir / "gemini_sell_license_valuation_latest.json"
    md_path = strategy_dir / f"gemini_sell_license_valuation_{tag}.md"
    md_latest = strategy_dir / "gemini_sell_license_valuation_latest.md"

    strategy_dir.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    json_latest.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# Gemini Sell/License/Keep Matrix",
        "",
        f"- Generated: `{generated_at}`",
        f"- Model: `{args.model}`",
        f"- Systems considered: `{len(selected)}`",
        "",
        "| system_id | name | decision | rationale | value_low_usd | value_high_usd | confidence |",
        "|---|---|---|---|---:|---:|---:|",
    ]
    for row in matrix_rows:
        lines.append(
            "| {system_id} | {name} | {decision} | {rationale} | {value_low_usd} | {value_high_usd} | {confidence_0_1} |".format(
                **row
            )
        )
    md_text = "\n".join(lines) + "\n"
    md_path.write_text(md_text, encoding="utf-8")
    md_latest.write_text(md_text, encoding="utf-8")

    print(
        json.dumps(
            {
                "status": "ok",
                "generated_at": generated_at,
                "outputs": {
                    "json_latest": str(json_latest),
                    "md_latest": str(md_latest),
                },
                "decision_counts": summary["decision_counts"],
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

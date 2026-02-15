#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPS_DIR="$GFT_ROOT/workspace/Maroon/Reports/Ops"
TMP_DIR="$GFT_ROOT/.tmp"
BQ_PROJECT_ID="${PROJECT_ID:-nanny-tech}"
BQ_DATASET="${DATASET:-maroon_ops}"
BQ_LOCATION="${BQ_LOCATION:-US}"
BQ_TABLE_PREFIX="${BQ_PROJECT_ID}:${BQ_DATASET}"
GCS_BUCKET="${GCS_BUCKET:-nanny-tech-core}"
GCS_PREFIX="${GCS_PREFIX:-maroon/ops/workspace/Maroon}"
GCS_BASE_URI="gs://${GCS_BUCKET}/${GCS_PREFIX}"
ENABLE_GEMINI_VALUATION="${ENABLE_GEMINI_VALUATION:-0}"
BQ_LOAD_RETRIES="${BQ_LOAD_RETRIES:-3}"
GCS_RETRIES="${GCS_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-2}"

mkdir -p "$TMP_DIR"

retry_cmd() {
  local retries="$1"
  shift
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if (( attempt >= retries )); then
      return 1
    fi
    sleep "$RETRY_SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
}

bq_load() {
  retry_cmd "$BQ_LOAD_RETRIES" \
    bq --project_id="$BQ_PROJECT_ID" --location="$BQ_LOCATION" load "$@"
}

bq_query() {
  local sql="$1"
  retry_cmd "$BQ_LOAD_RETRIES" \
    bq --project_id="$BQ_PROJECT_ID" --location="$BQ_LOCATION" query --use_legacy_sql=false "$sql"
}

bq_load_csv_existing() {
  local table="$1"
  local csv_file="$2"
  local query_table="${table/:/.}"
  bq_query "TRUNCATE TABLE \`$query_table\`"
  retry_cmd "$BQ_LOAD_RETRIES" \
    bq --project_id="$BQ_PROJECT_ID" --location="$BQ_LOCATION" load \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$table" "$csv_file"
}

gcs_cp() {
  retry_cmd "$GCS_RETRIES" gsutil cp "$@"
}

gcs_rsync() {
  retry_cmd "$GCS_RETRIES" gsutil -m rsync "$@"
}

python3 "$GFT_ROOT/scripts/build_complete_picture_pack.py"
python3 "$GFT_ROOT/scripts/auto_promote_hidden_gems.py" --top-n "${TOP_N:-12}" --push-firebase
python3 "$GFT_ROOT/scripts/build_counsel_trust_packet.py" \
  --publish-to-bigquery \
  --project-id "$BQ_PROJECT_ID" \
  --dataset "$BQ_DATASET"
python3 "$GFT_ROOT/scripts/build_ownership_and_handoff_pack.py" \
  --publish-to-bigquery \
  --project-id "$BQ_PROJECT_ID" \
  --dataset "$BQ_DATASET"
python3 "$GFT_ROOT/scripts/build_hidden_gems_docket.py" --top "${TOP_GEMS:-17}"
python3 "$GFT_ROOT/scripts/run_db_embedding_forensic_inspector.py" \
  --project-id "$BQ_PROJECT_ID" \
  --dataset "$BQ_DATASET"
python3 "$GFT_ROOT/scripts/run_red_team6_audit.py" \
  --project-id "$BQ_PROJECT_ID" \
  --dataset "$BQ_DATASET"
python3 "$GFT_ROOT/scripts/build_corpus_sql_pack.py" \
  --max-dedupe-bytes "${CORPUS_MAX_DEDUPE_BYTES:-180000}" \
  --max-dedupe-files "${CORPUS_MAX_DEDUPE_FILES:-1200}" \
  --priority-line-fallback-limit "${CORPUS_PRIORITY_LINE_FALLBACK_LIMIT:-400}" \
  --line-timeout-seconds "${CORPUS_LINE_TIMEOUT_SECONDS:-0.6}"
python3 "$GFT_ROOT/scripts/build_phase_readiness_gate.py"
if [[ "$ENABLE_GEMINI_VALUATION" == "1" ]]; then
  python3 "$GFT_ROOT/scripts/build_gemini_sell_license_matrix.py"
fi

SUMMARY_JSON="$OPS_DIR/maroon_complete_picture_snapshot_latest.json"
REGISTRY_CSV="$OPS_DIR/maroon_complete_picture_system_registry_latest.csv"
TICKETS_CSV="$OPS_DIR/auto_promoted_execution_tickets_latest.csv"
COUNSEL_QUEUE_CSV="$OPS_DIR/maroon_counsel_ip_execution_queue_latest.csv"
OWNERSHIP_CSV="$OPS_DIR/maroon_asset_ownership_registry_latest.csv"
OWNERSHIP_SUMMARY_JSON="$OPS_DIR/maroon_asset_ownership_summary_latest.json"
HIDDEN_GEMS_CSV="$OPS_DIR/maroon_hidden_gems_mission_docket_latest.csv"
HIDDEN_GEMS_MD="$OPS_DIR/maroon_hidden_gems_mission_docket_latest.md"
FORENSIC_MD="$OPS_DIR/maroon_db_embedding_forensic_inspection_latest.md"
FORENSIC_JSON="$OPS_DIR/maroon_db_embedding_forensic_inspection_latest.json"
REDTEAM_JSON="$OPS_DIR/maroon_red_team6_audit_latest.json"
REDTEAM_CSV="$OPS_DIR/maroon_red_team6_gap_register_latest.csv"
CORPUS_INVENTORY_CSV="$OPS_DIR/maroon_corpus_file_inventory_latest.csv"
CORPUS_GAP_CSV="$OPS_DIR/maroon_corpus_gap_register_latest.csv"
CORPUS_SNAPSHOT_JSON="$OPS_DIR/maroon_corpus_quality_snapshot_latest.json"
CORPUS_SNAPSHOT_MD="$OPS_DIR/maroon_corpus_quality_snapshot_latest.md"
PHASE_GATE_JSON="$OPS_DIR/maroon_phase_readiness_gate_latest.json"
PHASE_GATE_MD="$OPS_DIR/maroon_phase_readiness_gate_latest.md"
BUSINESS_OVERVIEW_MD="$GFT_ROOT/workspace/Maroon/Reports/Strategy/maroon_business_system_overview_latest.md"
HANDOFF_SPEC_MD="$GFT_ROOT/workspace/Maroon/Reports/Strategy/maroon_engineering_partner_handoff_spec_latest.md"
PROTECTION_STANDARD_MD="$GFT_ROOT/workspace/Maroon/Reports/Strategy/maroon_ip_protection_and_disclosure_standard_latest.md"
COUNSEL_BRIEF_MD="$GFT_ROOT/workspace/Maroon/Reports/Strategy/maroon_counsel_trust_execution_brief_latest.md"
GEMINI_VALUATION_MD="$GFT_ROOT/workspace/Maroon/Reports/Strategy/gemini_sell_license_valuation_latest.md"
GEMINI_VALUATION_JSON="$GFT_ROOT/workspace/Maroon/Reports/Strategy/gemini_sell_license_valuation_latest.json"
RUN_NDJSON="$TMP_DIR/maroon_complete_picture_run.ndjson"
FORENSIC_NDJSON="$TMP_DIR/maroon_db_embedding_forensic_inspection.ndjson"
CORPUS_SNAPSHOT_NDJSON="$TMP_DIR/maroon_corpus_quality_snapshot.ndjson"
PHASE_GATE_NDJSON="$TMP_DIR/maroon_phase_readiness_gate.ndjson"

SUMMARY_JSON="$SUMMARY_JSON" RUN_NDJSON="$RUN_NDJSON" python3 - <<'PY'
import json
import os
from pathlib import Path
src = Path(os.environ["SUMMARY_JSON"])
dst = Path(os.environ["RUN_NDJSON"])
payload = json.loads(src.read_text(encoding='utf-8'))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
print(dst)
PY

FORENSIC_JSON="$FORENSIC_JSON" FORENSIC_NDJSON="$FORENSIC_NDJSON" python3 - <<'PY'
import json
import os
from pathlib import Path
src = Path(os.environ["FORENSIC_JSON"])
dst = Path(os.environ["FORENSIC_NDJSON"])
payload = json.loads(src.read_text(encoding='utf-8'))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
print(dst)
PY

CORPUS_SNAPSHOT_JSON="$CORPUS_SNAPSHOT_JSON" CORPUS_SNAPSHOT_NDJSON="$CORPUS_SNAPSHOT_NDJSON" python3 - <<'PY'
import json
import os
from pathlib import Path
src = Path(os.environ["CORPUS_SNAPSHOT_JSON"])
dst = Path(os.environ["CORPUS_SNAPSHOT_NDJSON"])
payload = json.loads(src.read_text(encoding='utf-8'))
payload["summary_json"] = json.dumps(payload, separators=(",", ":"))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
print(dst)
PY

PHASE_GATE_JSON="$PHASE_GATE_JSON" PHASE_GATE_NDJSON="$PHASE_GATE_NDJSON" python3 - <<'PY'
import json
import os
from pathlib import Path
src = Path(os.environ["PHASE_GATE_JSON"])
dst = Path(os.environ["PHASE_GATE_NDJSON"])
payload = json.loads(src.read_text(encoding='utf-8'))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
print(dst)
PY

bq_load --replace --autodetect --source_format=NEWLINE_DELIMITED_JSON "$BQ_TABLE_PREFIX.maroon_complete_picture_runs" "$RUN_NDJSON"
bq_load --replace --autodetect --source_format=CSV --skip_leading_rows=1 "$BQ_TABLE_PREFIX.maroon_complete_picture_system_registry" "$REGISTRY_CSV"
bq_load --replace --autodetect --source_format=CSV --skip_leading_rows=1 "$BQ_TABLE_PREFIX.maroon_execution_tickets" "$TICKETS_CSV"
bq_load --replace --autodetect --source_format=CSV --skip_leading_rows=1 "$BQ_TABLE_PREFIX.maroon_counsel_ip_queue" "$COUNSEL_QUEUE_CSV"
bq_load --replace --autodetect --source_format=CSV --skip_leading_rows=1 "$BQ_TABLE_PREFIX.maroon_asset_ownership_registry" "$OWNERSHIP_CSV"
bq_load --replace --autodetect --source_format=CSV --skip_leading_rows=1 "$BQ_TABLE_PREFIX.maroon_hidden_gems_docket" "$HIDDEN_GEMS_CSV"
bq_load_csv_existing "$BQ_TABLE_PREFIX.maroon_redteam_gap_register" "$REDTEAM_CSV"
bq_load --replace --autodetect --source_format=NEWLINE_DELIMITED_JSON "$BQ_TABLE_PREFIX.maroon_db_embedding_forensic_inspection" "$FORENSIC_NDJSON"
bq_load_csv_existing "$BQ_TABLE_PREFIX.maroon_corpus_file_inventory" "$CORPUS_INVENTORY_CSV"
bq_load_csv_existing "$BQ_TABLE_PREFIX.maroon_corpus_gap_register" "$CORPUS_GAP_CSV"
bq_load --replace --source_format=NEWLINE_DELIMITED_JSON \
  "$BQ_TABLE_PREFIX.maroon_corpus_quality_snapshots" "$CORPUS_SNAPSHOT_NDJSON"
bq_load --replace --source_format=NEWLINE_DELIMITED_JSON \
  "$BQ_TABLE_PREFIX.maroon_phase_readiness_gate" "$PHASE_GATE_NDJSON"

PROJECT_ID="$BQ_PROJECT_ID" DATASET="$BQ_DATASET" "$GFT_ROOT/scripts/build_command_center_live_status.sh"

gcs_cp "$OPS_DIR/maroon_command_center_live_status.md" \
  "$GCS_BASE_URI/Reports/Ops/maroon_command_center_live_status.md"
gcs_cp "$OPS_DIR/maroon_complete_picture_snapshot_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_complete_picture_snapshot_latest.json"
gcs_cp "$OPS_DIR/maroon_complete_picture_system_registry_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_complete_picture_system_registry_latest.csv"
gcs_cp "$OPS_DIR/auto_promoted_execution_tickets_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/auto_promoted_execution_tickets_latest.csv"
gcs_cp "$OPS_DIR/auto_promoted_execution_runbook_latest.md" \
  "$GCS_BASE_URI/Reports/Ops/auto_promoted_execution_runbook_latest.md"
gcs_cp "$OPS_DIR/maroon_counsel_ip_execution_queue_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_counsel_ip_execution_queue_latest.csv"
gcs_cp "$OPS_DIR/maroon_asset_ownership_registry_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_asset_ownership_registry_latest.csv"
gcs_cp "$OPS_DIR/maroon_asset_ownership_summary_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_asset_ownership_summary_latest.json"
gcs_cp "$OPS_DIR/maroon_hidden_gems_mission_docket_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_hidden_gems_mission_docket_latest.csv"
gcs_cp "$OPS_DIR/maroon_hidden_gems_mission_docket_latest.md" \
  "$GCS_BASE_URI/Reports/Ops/maroon_hidden_gems_mission_docket_latest.md"
gcs_cp "$OPS_DIR/maroon_db_embedding_forensic_inspection_latest.md" \
  "$GCS_BASE_URI/Reports/Ops/maroon_db_embedding_forensic_inspection_latest.md"
gcs_cp "$OPS_DIR/maroon_db_embedding_forensic_inspection_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_db_embedding_forensic_inspection_latest.json"
gcs_cp "$OPS_DIR/maroon_red_team6_audit_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_red_team6_audit_latest.json"
gcs_cp "$OPS_DIR/maroon_red_team6_gap_register_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_red_team6_gap_register_latest.csv"
gcs_cp "$OPS_DIR/maroon_corpus_file_inventory_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_corpus_file_inventory_latest.csv"
gcs_cp "$OPS_DIR/maroon_corpus_gap_register_latest.csv" \
  "$GCS_BASE_URI/Reports/Ops/maroon_corpus_gap_register_latest.csv"
gcs_cp "$OPS_DIR/maroon_corpus_quality_snapshot_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_corpus_quality_snapshot_latest.json"
gcs_cp "$OPS_DIR/maroon_corpus_quality_snapshot_latest.md" \
  "$GCS_BASE_URI/Reports/Ops/maroon_corpus_quality_snapshot_latest.md"
gcs_cp "$OPS_DIR/maroon_phase_readiness_gate_latest.json" \
  "$GCS_BASE_URI/Reports/Ops/maroon_phase_readiness_gate_latest.json"
gcs_cp "$OPS_DIR/maroon_phase_readiness_gate_latest.md" \
  "$GCS_BASE_URI/Reports/Ops/maroon_phase_readiness_gate_latest.md"
gcs_cp "$BUSINESS_OVERVIEW_MD" \
  "$GCS_BASE_URI/Reports/Strategy/maroon_business_system_overview_latest.md"
gcs_cp "$HANDOFF_SPEC_MD" \
  "$GCS_BASE_URI/Reports/Strategy/maroon_engineering_partner_handoff_spec_latest.md"
gcs_cp "$PROTECTION_STANDARD_MD" \
  "$GCS_BASE_URI/Reports/Strategy/maroon_ip_protection_and_disclosure_standard_latest.md"
gcs_cp "$COUNSEL_BRIEF_MD" \
  "$GCS_BASE_URI/Reports/Strategy/maroon_counsel_trust_execution_brief_latest.md"
if [[ -f "$GEMINI_VALUATION_MD" ]]; then
  gcs_cp "$GEMINI_VALUATION_MD" \
    "$GCS_BASE_URI/Reports/Strategy/gemini_sell_license_valuation_latest.md"
fi
if [[ -f "$GEMINI_VALUATION_JSON" ]]; then
  gcs_cp "$GEMINI_VALUATION_JSON" \
    "$GCS_BASE_URI/Reports/Strategy/gemini_sell_license_valuation_latest.json"
fi
gcs_rsync -r "$OPS_DIR/runbooks/auto_promoted" \
  "$GCS_BASE_URI/Reports/Ops/runbooks/auto_promoted"

printf '{"status":"ok","cycle":"hourly_control_plane","ops_dir":"%s"}\n' "$OPS_DIR"

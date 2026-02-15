#!/usr/bin/env bash
set -euo pipefail

# Build MAROON SQL data layer from canonical operating registers.
# Modes:
#   TARGET=postgres  -> schema + load to PostgreSQL
#   TARGET=bigquery  -> schema + load to BigQuery
#   TARGET=all       -> both (default)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GFT_ROOT="$ROOT/Maroon-Core/google_free_tier"
SCRIPTS_DIR="$GFT_ROOT/scripts"
REGISTER_DIR="$GFT_ROOT/workspace/Maroon/Reports/operating_registers"
REPORTS_OPS_DIR="$GFT_ROOT/workspace/Maroon/Reports/Ops"
SQL_DIR="$GFT_ROOT/sql"
TMP_DIR="$GFT_ROOT/.tmp/sql_layer"
mkdir -p "$TMP_DIR" "$REPORTS_OPS_DIR"

TARGET="${TARGET:-all}"
PROJECT_ID="${PROJECT_ID:-nanny-tech}"
DATASET="${DATASET:-maroon_ops}"
BQ_LOCATION="${BQ_LOCATION:-US}"
POSTGRES_URL="${POSTGRES_URL:-}"
RUN_TS="$(date -u +%Y%m%dT%H%M%SZ)"

CONTRACT_JSON="$REPORTS_OPS_DIR/operating_schema_contract_${RUN_TS}.json"
CONTRACT_MD="$REPORTS_OPS_DIR/operating_schema_contract_${RUN_TS}.md"
GENERATED_PG_SQL="$SQL_DIR/generated/operating_contract_postgres.sql"
GENERATED_BQ_SQL="$SQL_DIR/generated/operating_contract_bigquery.sql"

POSTGRES_SCHEMA_SQL="$SQL_DIR/postgres/001_maroon_core_schema.sql"
BQ_SCHEMA_TEMPLATE="$SQL_DIR/bigquery/001_maroon_ops_schema.sql"
BQ_SCHEMA_RENDERED="$TMP_DIR/001_maroon_ops_schema.rendered.sql"
COMPLETE_PICTURE_SNAPSHOT_JSON="$REPORTS_OPS_DIR/maroon_complete_picture_snapshot_latest.json"
COMPLETE_PICTURE_RUN_NDJSON="$TMP_DIR/maroon_complete_picture_run.ndjson"
COMPLETE_PICTURE_RUN_PG_CSV="$TMP_DIR/maroon_complete_picture_run_pg.csv"
COMPLETE_PICTURE_REGISTRY_CSV="$REPORTS_OPS_DIR/maroon_complete_picture_system_registry_latest.csv"
EXECUTION_TICKETS_CSV="$REPORTS_OPS_DIR/auto_promoted_execution_tickets_latest.csv"
OWNERSHIP_CSV="$REPORTS_OPS_DIR/maroon_asset_ownership_registry_latest.csv"
COUNSEL_QUEUE_CSV="$REPORTS_OPS_DIR/maroon_counsel_ip_execution_queue_latest.csv"
REDTEAM_GAP_CSV="$REPORTS_OPS_DIR/maroon_red_team6_gap_register_latest.csv"
FORENSIC_JSON="$REPORTS_OPS_DIR/maroon_db_embedding_forensic_inspection_latest.json"
FORENSIC_NDJSON="$TMP_DIR/maroon_db_embedding_forensic_inspection.ndjson"
CORPUS_INVENTORY_CSV="$REPORTS_OPS_DIR/maroon_corpus_file_inventory_latest.csv"
CORPUS_GAP_CSV="$REPORTS_OPS_DIR/maroon_corpus_gap_register_latest.csv"
CORPUS_SNAPSHOT_JSON="$REPORTS_OPS_DIR/maroon_corpus_quality_snapshot_latest.json"
CORPUS_SNAPSHOT_NDJSON="$TMP_DIR/maroon_corpus_quality_snapshot.ndjson"
CORPUS_SNAPSHOT_PG_CSV="$TMP_DIR/maroon_corpus_quality_snapshot_pg.csv"
PHASE_GATE_JSON="$REPORTS_OPS_DIR/maroon_phase_readiness_gate_latest.json"
PHASE_GATE_NDJSON="$TMP_DIR/maroon_phase_readiness_gate.ndjson"
PHASE_GATE_PG_CSV="$TMP_DIR/maroon_phase_readiness_gate_pg.csv"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: missing required file: $file" >&2
    exit 1
  fi
}

run_contract_validation() {
  require_file "$REGISTER_DIR/data_model_spec.json"
  "$SCRIPTS_DIR/sync_operating_schema_contract.py" \
    --spec "$REGISTER_DIR/data_model_spec.json" \
    --register-dir "$REGISTER_DIR" \
    --output-json "$CONTRACT_JSON" \
    --output-md "$CONTRACT_MD" \
    --output-pg-sql "$GENERATED_PG_SQL" \
    --output-bq-sql "$GENERATED_BQ_SQL"
}

render_complete_picture_run_files() {
  if [[ ! -f "$COMPLETE_PICTURE_SNAPSHOT_JSON" ]]; then
    return 0
  fi
  SNAPSHOT_JSON="$COMPLETE_PICTURE_SNAPSHOT_JSON" \
  NDJSON_OUT="$COMPLETE_PICTURE_RUN_NDJSON" \
  PG_CSV_OUT="$COMPLETE_PICTURE_RUN_PG_CSV" \
  python3 - <<'PY'
import csv
import json
import os
from pathlib import Path

snapshot = Path(os.environ["SNAPSHOT_JSON"])
ndjson_out = Path(os.environ["NDJSON_OUT"])
pg_csv_out = Path(os.environ["PG_CSV_OUT"])

if not snapshot.exists():
    raise SystemExit(0)

data = json.loads(snapshot.read_text(encoding="utf-8"))
row = {
    "run_id": data.get("run_id", ""),
    "generated_at": data.get("generated_at", ""),
    "systems_total": data.get("systems_total"),
    "systems_after_compression": data.get("systems_after_compression"),
    "systems_before": data.get("systems_before"),
    "structural_review_count": data.get("structural_review_count"),
    "invention_candidates_count": data.get("invention_candidates_count"),
    "deep_theme_count": data.get("deep_theme_count"),
    "artifact_count": data.get("artifact_count"),
    "alignment_score": data.get("alignment_score"),
    "open_gap_ids": data.get("open_gap_ids", []),
    "source_snapshot_uri": str(snapshot),
}

ndjson_out.write_text(json.dumps(row, separators=(",", ":")) + "\n", encoding="utf-8")

pg_fieldnames = [
    "run_id",
    "generated_at",
    "systems_total",
    "systems_after_compression",
    "systems_before",
    "structural_review_count",
    "invention_candidates_count",
    "deep_theme_count",
    "artifact_count",
    "alignment_score",
    "open_gap_ids",
    "source_snapshot_uri",
]
with pg_csv_out.open("w", encoding="utf-8", newline="") as fh:
    writer = csv.DictWriter(fh, fieldnames=pg_fieldnames)
    writer.writeheader()
    row["open_gap_ids"] = json.dumps(row["open_gap_ids"])
    writer.writerow(row)
PY
}

render_forensic_snapshot_ndjson() {
  if [[ ! -f "$FORENSIC_JSON" ]]; then
    return 0
  fi
  FORENSIC_JSON="$FORENSIC_JSON" FORENSIC_NDJSON="$FORENSIC_NDJSON" python3 - <<'PY'
import json
import os
from pathlib import Path
src = Path(os.environ["FORENSIC_JSON"])
dst = Path(os.environ["FORENSIC_NDJSON"])
payload = json.loads(src.read_text(encoding='utf-8'))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
PY
}

render_corpus_snapshot_ndjson() {
  if [[ ! -f "$CORPUS_SNAPSHOT_JSON" ]]; then
    return 0
  fi
  CORPUS_SNAPSHOT_JSON="$CORPUS_SNAPSHOT_JSON" \
  CORPUS_SNAPSHOT_NDJSON="$CORPUS_SNAPSHOT_NDJSON" \
  CORPUS_SNAPSHOT_PG_CSV="$CORPUS_SNAPSHOT_PG_CSV" python3 - <<'PY'
import csv
import json
import os
from pathlib import Path
src = Path(os.environ["CORPUS_SNAPSHOT_JSON"])
dst = Path(os.environ["CORPUS_SNAPSHOT_NDJSON"])
pg_csv = Path(os.environ["CORPUS_SNAPSHOT_PG_CSV"])
payload = json.loads(src.read_text(encoding='utf-8'))
payload["summary_json"] = json.dumps(payload, separators=(",", ":"))
dst.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
fieldnames = [
  "run_id","generated_at","docs_total","text_docs_total","core_docs_total","core_text_docs_total",
  "priority_docs_total","priority_text_docs_total","line_coverage_pct","core_line_coverage_pct",
  "priority_line_coverage_pct","duplicate_groups_total","duplicate_docs_total","critical_missing_total",
  "open_gaps_total","avg_quality_score","core_avg_quality_score","priority_line_fallback_scans_used",
  "scan_state_complete","scan_state_processed","scan_state_candidates_total","summary_json"
]
pg_csv.parent.mkdir(parents=True, exist_ok=True)
with pg_csv.open("w", encoding="utf-8", newline="") as fh:
  writer = csv.DictWriter(fh, fieldnames=fieldnames)
  writer.writeheader()
  writer.writerow({k: payload.get(k, "") for k in fieldnames})
PY
}

render_phase_gate_files() {
  if [[ ! -f "$PHASE_GATE_JSON" ]]; then
    return 0
  fi
  PHASE_GATE_JSON="$PHASE_GATE_JSON" \
  PHASE_GATE_NDJSON="$PHASE_GATE_NDJSON" \
  PHASE_GATE_PG_CSV="$PHASE_GATE_PG_CSV" python3 - <<'PY'
import csv
import json
import os
from pathlib import Path
src = Path(os.environ["PHASE_GATE_JSON"])
ndjson = Path(os.environ["PHASE_GATE_NDJSON"])
pg_csv = Path(os.environ["PHASE_GATE_PG_CSV"])
payload = json.loads(src.read_text(encoding='utf-8'))
ndjson.write_text(json.dumps(payload, separators=(',', ':')) + '\n', encoding='utf-8')
fieldnames = [
  "generated_at","recommended_stage","readiness_level","metrics","hard_blockers",
  "warnings","forensic_health_status","run_id","operator_directive"
]
row = {k: payload.get(k, "") for k in fieldnames}
row["metrics"] = json.dumps(row["metrics"] if isinstance(row["metrics"], dict) else {}, separators=(",", ":"))
row["hard_blockers"] = json.dumps(row["hard_blockers"] if isinstance(row["hard_blockers"], list) else [], separators=(",", ":"))
row["warnings"] = json.dumps(row["warnings"] if isinstance(row["warnings"], list) else [], separators=(",", ":"))
pg_csv.parent.mkdir(parents=True, exist_ok=True)
with pg_csv.open("w", encoding="utf-8", newline="") as fh:
  writer = csv.DictWriter(fh, fieldnames=fieldnames)
  writer.writeheader()
  writer.writerow(row)
PY
}

bootstrap_postgres() {
  if ! command -v psql >/dev/null 2>&1; then
    echo "ERROR: psql is required for TARGET=postgres" >&2
    exit 1
  fi
  if [[ -z "$POSTGRES_URL" ]]; then
    echo "ERROR: POSTGRES_URL is required for TARGET=postgres" >&2
    exit 1
  fi

  require_file "$POSTGRES_SCHEMA_SQL"

  psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 -f "$POSTGRES_SCHEMA_SQL"

  psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE
  maroon_core.corpus_quality_snapshots,
  maroon_core.corpus_gap_register,
  maroon_core.corpus_file_inventory,
  maroon_core.asset_ownership_registry,
  maroon_core.counsel_ip_queue,
  maroon_core.ip_assets,
  maroon_core.budget_items,
  maroon_core.decision_records,
  maroon_core.spine_integrations,
  maroon_core.council_authority_matrix,
  maroon_core.inventions
RESTART IDENTITY;
SQL

  psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
\\copy maroon_core.inventions (
  invention_id,title,inventor,stage,evidence_refs,linked_systems,priority,next_action,owner,updated_at,
  confidentiality_class,disclosure_policy,github_issue_id,gcp_asset_uri,lineage_hash,last_sync_utc
) FROM '$REGISTER_DIR/inventions_registry.csv' CSV HEADER;

\\copy maroon_core.ip_assets (
  ip_id,linked_invention_id,asset_type,jurisdiction,filing_status,counsel_status,evidence_bundle_status,deadline,owner,updated_at,
  trade_secret_flag,public_disclosure_allowed,counsel_ticket_url,lineage_hash,last_sync_utc
) FROM '$REGISTER_DIR/ip_registry.csv' CSV HEADER;

\\copy maroon_core.budget_items (
  budget_id,category,initiative,amount_planned_usd,amount_actual_usd,variance_usd,approval_state,owner,updated_at
) FROM '$REGISTER_DIR/budget_registry.csv' CSV HEADER;

\\copy maroon_core.decision_records (
  decision_id,date,decider,context,decision,rationale,impact,reversal_rule,status
) FROM '$REGISTER_DIR/decision_log.csv' CSV HEADER;

\\copy maroon_core.spine_integrations (
  spine_id,layer,system,location,owner,sync_state,last_verified_utc
) FROM '$REGISTER_DIR/spine_integration_registry.csv' CSV HEADER;

\\copy maroon_core.council_authority_matrix (
  authority_id,domain,gate_condition,required_approver,approval_artifact,status
) FROM '$REGISTER_DIR/council_authority_matrix.csv' CSV HEADER;
SQL

  if [[ -f "$COMPLETE_PICTURE_RUN_PG_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.complete_picture_runs;
\\copy maroon_core.complete_picture_runs (
  run_id,generated_at,systems_total,systems_after_compression,systems_before,structural_review_count,invention_candidates_count,deep_theme_count,artifact_count,alignment_score,open_gap_ids,source_snapshot_uri
) FROM '$COMPLETE_PICTURE_RUN_PG_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$COMPLETE_PICTURE_REGISTRY_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.complete_picture_system_registry;
\\copy maroon_core.complete_picture_system_registry (
  system_id,name,system_type,ontology_layer,pillar_id,module_id,submodule_id,confidence_score,source_count,deep_signal_score,strategic_score,structural_review,recommended_commercial_action,readiness_stage,value_band_usd,monetization_path,signals,next_action,evidence_refs,origin
) FROM '$COMPLETE_PICTURE_REGISTRY_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$EXECUTION_TICKETS_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.execution_tickets;
\\copy maroon_core.execution_tickets (
  ticket_id,title,system_id,system_name,theme_id,theme_title,pillar_id,module_id,priority,status,owner,target_date,recommended_commercial_action,readiness_stage,strategic_score,deep_theme_score,value_band_usd,objective,kpi,next_action,evidence_refs,runbook_path,push_status
) FROM '$EXECUTION_TICKETS_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$OWNERSHIP_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.asset_ownership_registry;
\\copy maroon_core.asset_ownership_registry (
  asset_id,asset_category,asset_name,owner,owner_source,ownership_classification,ip_position,protection_level,disclosure_policy,primary_system_id,pillar_id,module_id,commercialization_action,readiness_stage,source_ref,lineage_hash,last_verified_utc
) FROM '$OWNERSHIP_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$COUNSEL_QUEUE_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.counsel_ip_queue;
\\copy maroon_core.counsel_ip_queue (
  queue_id,ip_id,invention_id,invention_title,asset_type,jurisdiction,current_filing_status,counsel_status,evidence_bundle_status,deadline,days_to_deadline,priority,queue_status,risk_level,required_counsel_action,required_engineering_action,trust_relevance,owner,target_counsel_date,last_updated_utc
) FROM '$COUNSEL_QUEUE_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$CORPUS_INVENTORY_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.corpus_file_inventory;
\\copy maroon_core.corpus_file_inventory (
  doc_id,source_path,bytes,mtime_utc,extension,is_text,priority_weight,source_tags,scope_class,line_count,line_scan_status,dedupe_hash,duplicate_group_size,quality_score,gap_flags,last_scanned_utc
) FROM '$CORPUS_INVENTORY_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$CORPUS_GAP_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.corpus_gap_register;
\\copy maroon_core.corpus_gap_register (
  gap_id,severity,gap_type,source_path,detail,recommended_action,status,created_at_utc
) FROM '$CORPUS_GAP_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$CORPUS_SNAPSHOT_PG_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.corpus_quality_snapshots;
\copy maroon_core.corpus_quality_snapshots (
  run_id,generated_at,docs_total,text_docs_total,core_docs_total,core_text_docs_total,
  priority_docs_total,priority_text_docs_total,line_coverage_pct,core_line_coverage_pct,
  priority_line_coverage_pct,duplicate_groups_total,duplicate_docs_total,critical_missing_total,
  open_gaps_total,avg_quality_score,core_avg_quality_score,priority_line_fallback_scans_used,
  scan_state_complete,scan_state_processed,scan_state_candidates_total,summary_json
) FROM '$CORPUS_SNAPSHOT_PG_CSV' CSV HEADER;
SQL
  fi

  if [[ -f "$PHASE_GATE_PG_CSV" ]]; then
    psql "$POSTGRES_URL" -v ON_ERROR_STOP=1 <<SQL
TRUNCATE TABLE maroon_core.phase_readiness_gate;
\\copy maroon_core.phase_readiness_gate (
  generated_at,recommended_stage,readiness_level,metrics,hard_blockers,warnings,forensic_health_status,run_id,operator_directive
) FROM '$PHASE_GATE_PG_CSV' CSV HEADER;
SQL
  fi

  echo "PostgreSQL bootstrap completed."
}

render_bigquery_sql() {
  require_file "$BQ_SCHEMA_TEMPLATE"
  sed \
    -e "s/__PROJECT_ID__/$PROJECT_ID/g" \
    -e "s/__DATASET__/$DATASET/g" \
    "$BQ_SCHEMA_TEMPLATE" > "$BQ_SCHEMA_RENDERED"
}

ensure_bigquery_dataset() {
  if ! command -v bq >/dev/null 2>&1; then
    echo "ERROR: bq is required for TARGET=bigquery" >&2
    exit 1
  fi
  if ! bq --project_id="$PROJECT_ID" show --dataset "$DATASET" >/dev/null 2>&1; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" mk --dataset \
      --description "MAROON operational SQL data layer" \
      "$DATASET"
  fi
}

bootstrap_bigquery() {
  ensure_bigquery_dataset
  render_bigquery_sql

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" query --use_legacy_sql=false < "$BQ_SCHEMA_RENDERED"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.inventions" "$REGISTER_DIR/inventions_registry.csv" \
    "invention_id:STRING,title:STRING,inventor:STRING,stage:STRING,evidence_refs:STRING,linked_systems:STRING,priority:STRING,next_action:STRING,owner:STRING,updated_at:TIMESTAMP,confidentiality_class:STRING,disclosure_policy:STRING,github_issue_id:STRING,gcp_asset_uri:STRING,lineage_hash:STRING,last_sync_utc:TIMESTAMP,source_snapshot_hash:STRING,created_at:TIMESTAMP"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.ip_assets" "$REGISTER_DIR/ip_registry.csv" \
    "ip_id:STRING,linked_invention_id:STRING,asset_type:STRING,jurisdiction:STRING,filing_status:STRING,counsel_status:STRING,evidence_bundle_status:STRING,deadline:DATE,owner:STRING,updated_at:TIMESTAMP,trade_secret_flag:BOOL,public_disclosure_allowed:BOOL,counsel_ticket_url:STRING,lineage_hash:STRING,last_sync_utc:TIMESTAMP,source_snapshot_hash:STRING,created_at:TIMESTAMP"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.budget_items" "$REGISTER_DIR/budget_registry.csv" \
    "budget_id:STRING,category:STRING,initiative:STRING,amount_planned_usd:NUMERIC,amount_actual_usd:NUMERIC,variance_usd:NUMERIC,approval_state:STRING,owner:STRING,updated_at:TIMESTAMP,source_snapshot_hash:STRING,created_at:TIMESTAMP"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.decision_records" "$REGISTER_DIR/decision_log.csv" \
    "decision_id:STRING,date:DATE,decider:STRING,context:STRING,decision:STRING,rationale:STRING,impact:STRING,reversal_rule:STRING,status:STRING,source_snapshot_hash:STRING,created_at:TIMESTAMP"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.spine_integrations" "$REGISTER_DIR/spine_integration_registry.csv" \
    "spine_id:STRING,layer:STRING,system:STRING,location:STRING,owner:STRING,sync_state:STRING,last_verified_utc:TIMESTAMP,source_snapshot_hash:STRING,created_at:TIMESTAMP"

  bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
    --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
    "$DATASET.council_authority_matrix" "$REGISTER_DIR/council_authority_matrix.csv" \
    "authority_id:STRING,domain:STRING,gate_condition:STRING,required_approver:STRING,approval_artifact:STRING,status:STRING,created_at:TIMESTAMP"

  if [[ -f "$COMPLETE_PICTURE_RUN_NDJSON" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --autodetect --source_format=NEWLINE_DELIMITED_JSON \
      "$DATASET.maroon_complete_picture_runs" "$COMPLETE_PICTURE_RUN_NDJSON"
  fi

  if [[ -f "$COMPLETE_PICTURE_REGISTRY_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_complete_picture_system_registry" "$COMPLETE_PICTURE_REGISTRY_CSV" \
      "system_id:STRING,name:STRING,system_type:STRING,ontology_layer:STRING,pillar_id:STRING,module_id:STRING,submodule_id:STRING,confidence_score:INT64,source_count:INT64,deep_signal_score:INT64,strategic_score:INT64,structural_review:BOOL,recommended_commercial_action:STRING,readiness_stage:STRING,value_band_usd:STRING,monetization_path:STRING,signals:STRING,next_action:STRING,evidence_refs:STRING,origin:STRING,created_at:TIMESTAMP"
  fi

  if [[ -f "$EXECUTION_TICKETS_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_execution_tickets" "$EXECUTION_TICKETS_CSV" \
      "ticket_id:STRING,title:STRING,system_id:STRING,system_name:STRING,theme_id:STRING,theme_title:STRING,pillar_id:STRING,module_id:STRING,priority:STRING,status:STRING,owner:STRING,target_date:DATE,recommended_commercial_action:STRING,readiness_stage:STRING,strategic_score:INT64,deep_theme_score:INT64,value_band_usd:STRING,objective:STRING,kpi:STRING,next_action:STRING,evidence_refs:STRING,runbook_path:STRING,push_status:STRING,created_at:TIMESTAMP"
  fi

  if [[ -f "$OWNERSHIP_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_asset_ownership_registry" "$OWNERSHIP_CSV" \
      "asset_id:STRING,asset_category:STRING,asset_name:STRING,owner:STRING,owner_source:STRING,ownership_classification:STRING,ip_position:STRING,protection_level:STRING,disclosure_policy:STRING,primary_system_id:STRING,pillar_id:STRING,module_id:STRING,commercialization_action:STRING,readiness_stage:STRING,source_ref:STRING,lineage_hash:STRING,last_verified_utc:TIMESTAMP,created_at:TIMESTAMP"
  fi

  if [[ -f "$COUNSEL_QUEUE_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_counsel_ip_queue" "$COUNSEL_QUEUE_CSV" \
      "queue_id:STRING,ip_id:STRING,invention_id:STRING,invention_title:STRING,asset_type:STRING,jurisdiction:STRING,current_filing_status:STRING,counsel_status:STRING,evidence_bundle_status:STRING,deadline:DATE,days_to_deadline:INT64,priority:STRING,queue_status:STRING,risk_level:STRING,required_counsel_action:STRING,required_engineering_action:STRING,trust_relevance:STRING,owner:STRING,target_counsel_date:DATE,last_updated_utc:TIMESTAMP,created_at:TIMESTAMP"
  fi

  if [[ -f "$REDTEAM_GAP_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_redteam_gap_register" "$REDTEAM_GAP_CSV" \
      "domain:STRING,severity:STRING,gap:STRING,impact:STRING,evidence:STRING,owner:STRING,fix_status:STRING,target_date:DATE,created_at:TIMESTAMP"
  fi

  if [[ -f "$FORENSIC_NDJSON" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --autodetect --source_format=NEWLINE_DELIMITED_JSON \
      "$DATASET.maroon_db_embedding_forensic_inspection" "$FORENSIC_NDJSON"
  fi

  if [[ -f "$CORPUS_INVENTORY_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_corpus_file_inventory" "$CORPUS_INVENTORY_CSV" \
      "doc_id:STRING,source_path:STRING,bytes:INT64,mtime_utc:TIMESTAMP,extension:STRING,is_text:BOOL,priority_weight:INT64,source_tags:STRING,scope_class:STRING,line_count:INT64,line_scan_status:STRING,dedupe_hash:STRING,duplicate_group_size:INT64,quality_score:FLOAT64,gap_flags:STRING,last_scanned_utc:TIMESTAMP,created_at:TIMESTAMP"
  fi

  if [[ -f "$CORPUS_GAP_CSV" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --allow_jagged_rows \
      "$DATASET.maroon_corpus_gap_register" "$CORPUS_GAP_CSV" \
      "gap_id:STRING,severity:STRING,gap_type:STRING,source_path:STRING,detail:STRING,recommended_action:STRING,status:STRING,created_at_utc:TIMESTAMP,created_at:TIMESTAMP"
  fi

  if [[ -f "$CORPUS_SNAPSHOT_NDJSON" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --autodetect --source_format=NEWLINE_DELIMITED_JSON \
      "$DATASET.maroon_corpus_quality_snapshots" "$CORPUS_SNAPSHOT_NDJSON"
  fi

  if [[ -f "$PHASE_GATE_NDJSON" ]]; then
    bq --project_id="$PROJECT_ID" --location="$BQ_LOCATION" load --replace \
      --autodetect --source_format=NEWLINE_DELIMITED_JSON \
      "$DATASET.maroon_phase_readiness_gate" "$PHASE_GATE_NDJSON"
  fi

  echo "BigQuery bootstrap completed."
}

run_contract_validation
render_complete_picture_run_files
render_forensic_snapshot_ndjson
render_corpus_snapshot_ndjson
render_phase_gate_files

case "$TARGET" in
  postgres)
    bootstrap_postgres
    ;;
  bigquery)
    bootstrap_bigquery
    ;;
  all)
    bootstrap_postgres
    bootstrap_bigquery
    ;;
  *)
    echo "ERROR: TARGET must be one of: postgres, bigquery, all" >&2
    exit 1
    ;;
esac

echo "SQL layer bootstrap done (target=$TARGET)."
echo "Contract JSON: $CONTRACT_JSON"
echo "Contract MD: $CONTRACT_MD"

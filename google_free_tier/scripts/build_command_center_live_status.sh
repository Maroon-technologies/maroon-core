#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GFT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$GFT_ROOT/workspace/Maroon/Reports/Ops"
OUT_FILE="$OUT_DIR/maroon_command_center_live_status.md"
PROJECT_ID="${PROJECT_ID:-nanny-tech}"
DATASET="${DATASET:-maroon_ops}"

mkdir -p "$OUT_DIR"

now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_query_json() {
  local sql="$1"
  bq --project_id="$PROJECT_ID" query --use_legacy_sql=false --format=json "$sql" 2>/dev/null || echo "[]"
}

overview_json="$(run_query_json "SELECT * FROM \`$PROJECT_ID.$DATASET.executive_data_plane_overview\`")"
arch_json="$(run_query_json "SELECT run_id, generated_at, systems_before, systems_after_compression, embedding_backend FROM \`$PROJECT_ID.$DATASET.maroon_architecture_runs\` ORDER BY generated_at DESC LIMIT 1")"
lineage_json="$(run_query_json "SELECT run_id, COUNT(*) AS lineage_rows FROM \`$PROJECT_ID.$DATASET.maroon_architecture_lineage\` GROUP BY run_id ORDER BY run_id DESC LIMIT 1")"
complete_picture_run_json="$(run_query_json "SELECT run_id, generated_at, systems_total, systems_after_compression, structural_review_count, invention_candidates_count, artifact_count, alignment_score FROM \`$PROJECT_ID.$DATASET.maroon_complete_picture_runs\` ORDER BY generated_at DESC LIMIT 1")"
complete_picture_registry_json="$(run_query_json "SELECT COUNT(*) AS registry_rows FROM \`$PROJECT_ID.$DATASET.maroon_complete_picture_system_registry\`")"
tickets_json="$(run_query_json "SELECT COUNT(*) AS tickets_total, COALESCE(SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END), 0) AS tickets_open, COALESCE(SUM(CASE WHEN priority = 'P1' AND status = 'open' THEN 1 ELSE 0 END), 0) AS p1_open FROM \`$PROJECT_ID.$DATASET.maroon_execution_tickets\`")"
legal_queue_json="$(run_query_json "SELECT COUNT(*) AS queue_total, COALESCE(SUM(CASE WHEN priority = 'P0' THEN 1 ELSE 0 END), 0) AS p0_count, COALESCE(SUM(CASE WHEN priority = 'P1' THEN 1 ELSE 0 END), 0) AS p1_count, COALESCE(SUM(CASE WHEN queue_status = 'evidence_bundle_required' THEN 1 ELSE 0 END), 0) AS evidence_bundle_required FROM \`$PROJECT_ID.$DATASET.maroon_counsel_ip_queue\`")"
redteam_json="$(run_query_json "SELECT COUNT(*) AS open_gaps, COALESCE(SUM(CASE WHEN severity = 'P0' THEN 1 ELSE 0 END), 0) AS p0_gaps, COALESCE(SUM(CASE WHEN severity = 'P1' THEN 1 ELSE 0 END), 0) AS p1_gaps, COALESCE(SUM(CASE WHEN severity = 'P2' THEN 1 ELSE 0 END), 0) AS p2_gaps FROM \`$PROJECT_ID.$DATASET.maroon_redteam_gap_register\`")"
forensic_json="$(run_query_json "SELECT generated_at, health_status, ARRAY_LENGTH(health_flags) AS health_flag_count FROM \`$PROJECT_ID.$DATASET.maroon_db_embedding_forensic_inspection\` ORDER BY generated_at DESC LIMIT 1")"
ownership_json="$(run_query_json "SELECT COUNT(*) AS ownership_rows, COUNT(DISTINCT owner) AS owners_distinct FROM \`$PROJECT_ID.$DATASET.maroon_asset_ownership_registry\`")"
corpus_quality_json="$(run_query_json "SELECT run_id, generated_at, docs_total, text_docs_total, core_docs_total, core_text_docs_total, priority_docs_total, priority_text_docs_total, line_coverage_pct, core_line_coverage_pct, priority_line_coverage_pct, avg_quality_score, core_avg_quality_score, open_gaps_total, critical_missing_total FROM \`$PROJECT_ID.$DATASET.maroon_corpus_quality_overview\`")"
corpus_gaps_json="$(run_query_json "SELECT COUNT(*) AS gap_rows, COALESCE(SUM(CASE WHEN severity = 'P0' THEN 1 ELSE 0 END), 0) AS p0_gaps, COALESCE(SUM(CASE WHEN severity = 'P1' THEN 1 ELSE 0 END), 0) AS p1_gaps FROM \`$PROJECT_ID.$DATASET.maroon_corpus_gap_register\`")"

{
  echo "# MAROON Command Center Live Status"
  echo
  echo "Generated: $now_utc"
  echo
  echo "## BigQuery Overview"
  echo
  echo '```json'
  echo "$overview_json"
  echo '```'
  echo
  echo "## Latest Architecture Run"
  echo
  echo '```json'
  echo "$arch_json"
  echo '```'
  echo
  echo "## Latest Lineage Row Count"
  echo
  echo '```json'
  echo "$lineage_json"
  echo '```'
  echo
  echo "## Complete Picture Run"
  echo
  echo '```json'
  echo "$complete_picture_run_json"
  echo '```'
  echo
  echo "## Complete Picture Registry"
  echo
  echo '```json'
  echo "$complete_picture_registry_json"
  echo '```'
  echo
  echo "## Execution Tickets"
  echo
  echo '```json'
  echo "$tickets_json"
  echo '```'
  echo
  echo "## Counsel IP Queue"
  echo
  echo '```json'
  echo "$legal_queue_json"
  echo '```'
  echo
  echo "## Red Team Gap Register"
  echo
  echo '```json'
  echo "$redteam_json"
  echo '```'
  echo
  echo "## Latest Forensic Snapshot"
  echo
  echo '```json'
  echo "$forensic_json"
  echo '```'
  echo
  echo "## Ownership Registry"
  echo
  echo '```json'
  echo "$ownership_json"
  echo '```'
  echo
  echo "## Corpus Quality"
  echo
  echo '```json'
  echo "$corpus_quality_json"
  echo '```'
  echo
  echo "## Corpus Gaps"
  echo
  echo '```json'
  echo "$corpus_gaps_json"
  echo '```'
} > "$OUT_FILE"

printf '{"status":"ok","out_file":"%s"}\n' "$OUT_FILE"

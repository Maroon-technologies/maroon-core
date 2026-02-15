-- MAROON core analytics schema (BigQuery Standard SQL)
-- Rendered by bootstrap script with __PROJECT_ID__ and __DATASET__ replacements.

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.inventions` (
  invention_id STRING NOT NULL,
  title STRING NOT NULL,
  inventor STRING NOT NULL,
  stage STRING NOT NULL,
  evidence_refs STRING,
  linked_systems STRING,
  priority STRING,
  next_action STRING,
  owner STRING NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  confidentiality_class STRING,
  disclosure_policy STRING,
  github_issue_id STRING,
  gcp_asset_uri STRING,
  lineage_hash STRING,
  last_sync_utc TIMESTAMP,
  source_snapshot_hash STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(updated_at)
CLUSTER BY priority, owner
OPTIONS(description = 'Invention registry from canonical operating registers');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.ip_assets` (
  ip_id STRING NOT NULL,
  linked_invention_id STRING,
  asset_type STRING NOT NULL,
  jurisdiction STRING,
  filing_status STRING NOT NULL,
  counsel_status STRING,
  evidence_bundle_status STRING,
  deadline DATE,
  owner STRING NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  trade_secret_flag BOOL,
  public_disclosure_allowed BOOL,
  counsel_ticket_url STRING,
  lineage_hash STRING,
  last_sync_utc TIMESTAMP,
  source_snapshot_hash STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(updated_at)
CLUSTER BY filing_status, owner
OPTIONS(description = 'IP register linked to inventions');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.inventions_registry_mirror` (
  invention_id STRING NOT NULL,
  title STRING NOT NULL,
  inventor STRING,
  stage STRING NOT NULL,
  evidence_refs STRING,
  linked_systems STRING,
  priority STRING,
  next_action STRING,
  owner STRING NOT NULL,
  updated_at TIMESTAMP,
  confidentiality_class STRING,
  disclosure_policy STRING,
  github_issue_id STRING,
  gcp_asset_uri STRING,
  lineage_hash STRING NOT NULL,
  last_sync_utc TIMESTAMP,
  sync_run_id STRING,
  synced_at TIMESTAMP,
  source_sha256 STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY stage, owner
OPTIONS(description = 'Pre-patent canonical invention mirror with legal protection fields');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.ip_registry_mirror` (
  ip_id STRING NOT NULL,
  linked_invention_id STRING,
  asset_type STRING,
  jurisdiction STRING,
  filing_status STRING NOT NULL,
  counsel_status STRING,
  evidence_bundle_status STRING,
  deadline DATE,
  owner STRING NOT NULL,
  updated_at TIMESTAMP,
  trade_secret_flag BOOL,
  public_disclosure_allowed BOOL,
  counsel_ticket_url STRING,
  lineage_hash STRING NOT NULL,
  last_sync_utc TIMESTAMP,
  sync_run_id STRING,
  synced_at TIMESTAMP,
  source_sha256 STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY filing_status, owner
OPTIONS(description = 'Pre-patent IP mirror with disclosure and counsel-gate controls');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.invention_sync_audit` (
  entity_type STRING NOT NULL,
  entity_id STRING NOT NULL,
  source_sha256 STRING NOT NULL,
  target STRING NOT NULL,
  status STRING NOT NULL,
  error_detail STRING,
  synced_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(synced_at)
CLUSTER BY target, status
OPTIONS(description = 'Per-entity sync audit log for local/GCP/GitHub invention marking');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.budget_items` (
  budget_id STRING NOT NULL,
  category STRING NOT NULL,
  initiative STRING NOT NULL,
  amount_planned_usd NUMERIC NOT NULL,
  amount_actual_usd NUMERIC NOT NULL,
  variance_usd NUMERIC NOT NULL,
  approval_state STRING NOT NULL,
  owner STRING NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  source_snapshot_hash STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(updated_at)
CLUSTER BY category, approval_state
OPTIONS(description = 'Budget register for operating initiatives');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.decision_records` (
  decision_id STRING NOT NULL,
  date DATE NOT NULL,
  decider STRING NOT NULL,
  context STRING NOT NULL,
  decision STRING NOT NULL,
  rationale STRING,
  impact STRING,
  reversal_rule STRING,
  status STRING NOT NULL,
  source_snapshot_hash STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY date
CLUSTER BY status, decider
OPTIONS(description = 'Decision log and governance traceability');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.spine_integrations` (
  spine_id STRING NOT NULL,
  layer STRING NOT NULL,
  system STRING NOT NULL,
  location STRING NOT NULL,
  owner STRING NOT NULL,
  sync_state STRING NOT NULL,
  last_verified_utc TIMESTAMP,
  source_snapshot_hash STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY layer, sync_state
OPTIONS(description = 'Spine integration registry for platform connectivity');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.council_authority_matrix` (
  authority_id STRING NOT NULL,
  domain STRING NOT NULL,
  gate_condition STRING NOT NULL,
  required_approver STRING NOT NULL,
  approval_artifact STRING,
  status STRING NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY domain, status
OPTIONS(description = 'Authority model and approval gates');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.artifact_registry` (
  artifact_id STRING NOT NULL,
  artifact_type STRING NOT NULL,
  artifact_hash STRING NOT NULL,
  source_lineage ARRAY<STRING>,
  model_used STRING,
  cost_breakdown_usd NUMERIC,
  credits_used NUMERIC,
  storage_uri STRING,
  created_by STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY artifact_type
OPTIONS(description = 'Generated media/docs valuation artifacts with lineage');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.lineage_edges` (
  edge_id STRING NOT NULL,
  from_entity STRING NOT NULL,
  to_entity STRING NOT NULL,
  relation_type STRING NOT NULL,
  evidence_ref STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY relation_type
OPTIONS(description = 'Lineage edges between records/artifacts/systems');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.valuation_registry` (
  valuation_id STRING NOT NULL,
  subject_id STRING NOT NULL,
  subject_type STRING NOT NULL,
  valuation_method STRING NOT NULL,
  low_usd NUMERIC,
  base_usd NUMERIC,
  high_usd NUMERIC,
  confidence_score NUMERIC,
  notes STRING,
  approved_by STRING,
  approved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY subject_type, valuation_method
OPTIONS(description = 'Valuation scenarios and commercial decision support');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_complete_picture_runs` (
  run_id STRING NOT NULL,
  generated_at TIMESTAMP NOT NULL,
  systems_total INT64,
  systems_after_compression INT64,
  systems_before INT64,
  structural_review_count INT64,
  invention_candidates_count INT64,
  deep_theme_count INT64,
  artifact_count INT64,
  alignment_score FLOAT64,
  open_gap_ids ARRAY<STRING>,
  source_snapshot_uri STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(generated_at)
CLUSTER BY run_id
OPTIONS(description = 'Complete-picture summary runs for MAROON command center');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_complete_picture_system_registry` (
  system_id STRING NOT NULL,
  name STRING NOT NULL,
  system_type STRING,
  ontology_layer STRING,
  pillar_id STRING,
  module_id STRING,
  submodule_id STRING,
  confidence_score INT64,
  source_count INT64,
  deep_signal_score INT64,
  strategic_score INT64,
  structural_review BOOL,
  recommended_commercial_action STRING,
  readiness_stage STRING,
  value_band_usd STRING,
  monetization_path STRING,
  signals STRING,
  next_action STRING,
  evidence_refs STRING,
  origin STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY pillar_id, recommended_commercial_action
OPTIONS(description = 'Canonical complete-picture system registry');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_execution_tickets` (
  ticket_id STRING NOT NULL,
  title STRING NOT NULL,
  system_id STRING,
  system_name STRING,
  theme_id STRING,
  theme_title STRING,
  pillar_id STRING,
  module_id STRING,
  priority STRING,
  status STRING,
  owner STRING,
  target_date DATE,
  recommended_commercial_action STRING,
  readiness_stage STRING,
  strategic_score INT64,
  deep_theme_score INT64,
  value_band_usd STRING,
  objective STRING,
  kpi STRING,
  next_action STRING,
  evidence_refs STRING,
  runbook_path STRING,
  push_status STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY priority, status
OPTIONS(description = 'Auto-promoted execution tickets and runbook links');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_counsel_ip_queue` (
  queue_id STRING NOT NULL,
  ip_id STRING NOT NULL,
  invention_id STRING,
  invention_title STRING,
  asset_type STRING,
  jurisdiction STRING,
  current_filing_status STRING,
  counsel_status STRING,
  evidence_bundle_status STRING,
  deadline DATE,
  days_to_deadline INT64,
  priority STRING,
  queue_status STRING,
  risk_level STRING,
  required_counsel_action STRING,
  required_engineering_action STRING,
  trust_relevance STRING,
  owner STRING,
  target_counsel_date DATE,
  last_updated_utc TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY priority, queue_status
OPTIONS(description = 'Counsel execution queue for IP filing and trust governance');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_asset_ownership_registry` (
  asset_id STRING NOT NULL,
  asset_category STRING NOT NULL,
  asset_name STRING,
  owner STRING NOT NULL,
  owner_source STRING,
  ownership_classification STRING,
  ip_position STRING,
  protection_level STRING,
  disclosure_policy STRING,
  primary_system_id STRING,
  pillar_id STRING,
  module_id STRING,
  commercialization_action STRING,
  readiness_stage STRING,
  source_ref STRING,
  lineage_hash STRING,
  last_verified_utc TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY asset_category, owner
OPTIONS(description = 'Ownership and disclosure control registry for systems, inventions, IP assets, and artifacts');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_redteam_gap_register` (
  domain STRING,
  severity STRING,
  gap STRING,
  impact STRING,
  evidence STRING,
  owner STRING,
  fix_status STRING,
  target_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY severity, domain
OPTIONS(description = 'Red Team 6 gap register');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_db_embedding_forensic_inspection` (
  generated_at TIMESTAMP,
  project_id STRING,
  dataset STRING,
  latest_architecture_run JSON,
  lineage_stats JSON,
  table_counts JSON,
  system_integrity JSON,
  ownership_integrity JSON,
  execution_integrity JSON,
  health_flags ARRAY<STRING>,
  health_status STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY health_status
OPTIONS(description = 'Forensic DB + embedding inspection snapshots');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_corpus_file_inventory` (
  doc_id STRING NOT NULL,
  source_path STRING NOT NULL,
  bytes INT64 NOT NULL,
  mtime_utc TIMESTAMP,
  extension STRING,
  is_text BOOL,
  priority_weight INT64,
  source_tags STRING,
  scope_class STRING,
  line_count INT64,
  line_scan_status STRING,
  dedupe_hash STRING,
  duplicate_group_size INT64,
  quality_score FLOAT64,
  gap_flags STRING,
  last_scanned_utc TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY is_text, priority_weight, line_scan_status
OPTIONS(description = 'Corpus-wide file inventory enriched with quality and dedupe metadata');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_corpus_gap_register` (
  gap_id STRING NOT NULL,
  severity STRING NOT NULL,
  gap_type STRING NOT NULL,
  source_path STRING,
  detail STRING,
  recommended_action STRING,
  status STRING,
  created_at_utc TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY severity, gap_type
OPTIONS(description = 'Open corpus quality gaps requiring cleanup and adjudication');

CREATE TABLE IF NOT EXISTS `__PROJECT_ID__.__DATASET__.maroon_corpus_quality_snapshots` (
  run_id STRING NOT NULL,
  generated_at TIMESTAMP NOT NULL,
  docs_total INT64,
  text_docs_total INT64,
  core_docs_total INT64,
  core_text_docs_total INT64,
  priority_docs_total INT64,
  priority_text_docs_total INT64,
  line_coverage_pct FLOAT64,
  core_line_coverage_pct FLOAT64,
  priority_line_coverage_pct FLOAT64,
  duplicate_groups_total INT64,
  duplicate_docs_total INT64,
  critical_missing_total INT64,
  open_gaps_total INT64,
  avg_quality_score FLOAT64,
  core_avg_quality_score FLOAT64,
  priority_line_fallback_scans_used INT64,
  scan_state_complete BOOL,
  scan_state_processed INT64,
  scan_state_candidates_total INT64,
  summary_json JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(generated_at)
CLUSTER BY run_id
OPTIONS(description = 'Snapshot summary for corpus coverage, quality, and unresolved gaps');

CREATE OR REPLACE VIEW `__PROJECT_ID__.__DATASET__.maroon_corpus_quality_overview` AS
SELECT
  snapshot.run_id,
  snapshot.generated_at,
  snapshot.docs_total,
  snapshot.text_docs_total,
  snapshot.core_docs_total,
  snapshot.core_text_docs_total,
  snapshot.priority_docs_total,
  snapshot.priority_text_docs_total,
  snapshot.line_coverage_pct,
  snapshot.core_line_coverage_pct,
  snapshot.priority_line_coverage_pct,
  snapshot.duplicate_groups_total,
  snapshot.duplicate_docs_total,
  snapshot.critical_missing_total,
  snapshot.open_gaps_total,
  snapshot.avg_quality_score,
  snapshot.core_avg_quality_score,
  snapshot.priority_line_fallback_scans_used,
  snapshot.scan_state_complete,
  snapshot.scan_state_processed,
  snapshot.scan_state_candidates_total,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_file_inventory`) AS inventory_rows,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_gap_register`) AS gap_rows,
  CURRENT_TIMESTAMP() AS refreshed_at
FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_quality_snapshots` AS snapshot
QUALIFY ROW_NUMBER() OVER (ORDER BY generated_at DESC, run_id DESC) = 1;

CREATE OR REPLACE VIEW `__PROJECT_ID__.__DATASET__.executive_data_plane_overview` AS
SELECT
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.inventions`) AS inventions_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.ip_assets`) AS ip_assets_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.budget_items`) AS budget_items_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.decision_records`) AS decision_records_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.spine_integrations`) AS spine_integrations_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.council_authority_matrix`) AS authority_rules_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.artifact_registry`) AS artifacts_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_counsel_ip_queue`) AS counsel_queue_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_asset_ownership_registry`) AS ownership_registry_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_redteam_gap_register`) AS redteam_gap_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_db_embedding_forensic_inspection`) AS forensic_snapshot_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_file_inventory`) AS corpus_inventory_count,
  (SELECT COUNT(*) FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_gap_register`) AS corpus_gap_count,
  (
    SELECT AVG(quality_score)
    FROM `__PROJECT_ID__.__DATASET__.maroon_corpus_file_inventory`
  ) AS corpus_avg_quality_score,
  CURRENT_TIMESTAMP() AS refreshed_at;

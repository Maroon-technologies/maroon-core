-- MAROON core relational schema (PostgreSQL)
-- Deterministic and idempotent: safe to re-run.

CREATE SCHEMA IF NOT EXISTS maroon_core;

CREATE TABLE IF NOT EXISTS maroon_core.inventions (
  invention_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  inventor TEXT NOT NULL,
  stage TEXT NOT NULL,
  evidence_refs TEXT,
  linked_systems TEXT,
  priority TEXT,
  next_action TEXT,
  owner TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  confidentiality_class TEXT NOT NULL DEFAULT 'trade_secret',
  disclosure_policy TEXT NOT NULL DEFAULT 'internal_only',
  github_issue_id TEXT,
  gcp_asset_uri TEXT,
  lineage_hash TEXT,
  last_sync_utc TIMESTAMPTZ,
  source_snapshot_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inventions_id_format_chk CHECK (invention_id ~ '^INV-[0-9]{4}$'),
  CONSTRAINT inventions_stage_chk CHECK (
    stage IN ('captured', 'triaged', 'active_build', 'counsel_review', 'claim_draft_locked', 'filing_ready', 'on_hold')
  )
);

CREATE TABLE IF NOT EXISTS maroon_core.ip_assets (
  ip_id TEXT PRIMARY KEY,
  linked_invention_id TEXT,
  asset_type TEXT NOT NULL,
  jurisdiction TEXT,
  filing_status TEXT NOT NULL,
  counsel_status TEXT,
  evidence_bundle_status TEXT,
  deadline DATE,
  owner TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  trade_secret_flag BOOLEAN NOT NULL DEFAULT TRUE,
  public_disclosure_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  counsel_ticket_url TEXT,
  lineage_hash TEXT,
  last_sync_utc TIMESTAMPTZ,
  source_snapshot_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ip_assets_id_format_chk CHECK (ip_id ~ '^IP-[0-9]{4}$'),
  CONSTRAINT ip_assets_filing_status_chk CHECK (
    filing_status IN ('UNFILED_PATENT_CANDIDATE', 'TRADE_SECRET_LOCKED', 'PROVISIONAL_PLANNED', 'FILED', 'ABANDONED')
  ),
  CONSTRAINT ip_assets_counsel_status_chk CHECK (
    counsel_status IS NULL OR counsel_status IN ('open', 'evidence_bundle_required', 'under_review', 'approved', 'blocked')
  ),
  CONSTRAINT ip_assets_evidence_status_chk CHECK (
    evidence_bundle_status IS NULL OR evidence_bundle_status IN ('missing', 'draft', 'locked', 'verified')
  ),
  CONSTRAINT ip_assets_invention_fk FOREIGN KEY (linked_invention_id)
    REFERENCES maroon_core.inventions(invention_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS maroon_core.inventions_registry_mirror (
  invention_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  inventor TEXT,
  stage TEXT NOT NULL,
  evidence_refs TEXT,
  linked_systems TEXT,
  priority TEXT,
  next_action TEXT,
  owner TEXT NOT NULL,
  updated_at TIMESTAMPTZ,
  confidentiality_class TEXT,
  disclosure_policy TEXT,
  github_issue_id TEXT,
  gcp_asset_uri TEXT,
  lineage_hash TEXT NOT NULL,
  last_sync_utc TIMESTAMPTZ,
  sync_run_id TEXT,
  synced_at TIMESTAMPTZ,
  source_sha256 TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.ip_registry_mirror (
  ip_id TEXT PRIMARY KEY,
  linked_invention_id TEXT,
  asset_type TEXT,
  jurisdiction TEXT,
  filing_status TEXT NOT NULL,
  counsel_status TEXT,
  evidence_bundle_status TEXT,
  deadline DATE,
  owner TEXT NOT NULL,
  updated_at TIMESTAMPTZ,
  trade_secret_flag BOOLEAN NOT NULL DEFAULT TRUE,
  public_disclosure_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  counsel_ticket_url TEXT,
  lineage_hash TEXT NOT NULL,
  last_sync_utc TIMESTAMPTZ,
  sync_run_id TEXT,
  synced_at TIMESTAMPTZ,
  source_sha256 TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.invention_sync_audit (
  audit_id BIGSERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  source_sha256 TEXT NOT NULL,
  target TEXT NOT NULL,
  status TEXT NOT NULL,
  error_detail TEXT,
  synced_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.budget_items (
  budget_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  initiative TEXT NOT NULL,
  amount_planned_usd NUMERIC(14,2) NOT NULL DEFAULT 0,
  amount_actual_usd NUMERIC(14,2) NOT NULL DEFAULT 0,
  variance_usd NUMERIC(14,2) NOT NULL DEFAULT 0,
  approval_state TEXT NOT NULL,
  owner TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  source_snapshot_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT budget_items_id_format_chk CHECK (budget_id ~ '^BUD-[0-9]{4}$')
);

CREATE TABLE IF NOT EXISTS maroon_core.decision_records (
  decision_id TEXT PRIMARY KEY,
  date DATE NOT NULL,
  decider TEXT NOT NULL,
  context TEXT NOT NULL,
  decision TEXT NOT NULL,
  rationale TEXT,
  impact TEXT,
  reversal_rule TEXT,
  status TEXT NOT NULL,
  source_snapshot_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT decision_records_id_format_chk CHECK (decision_id ~ '^DEC-[0-9]{4}$')
);

CREATE TABLE IF NOT EXISTS maroon_core.spine_integrations (
  spine_id TEXT PRIMARY KEY,
  layer TEXT NOT NULL,
  system TEXT NOT NULL,
  location TEXT NOT NULL,
  owner TEXT NOT NULL,
  sync_state TEXT NOT NULL,
  last_verified_utc TIMESTAMPTZ,
  source_snapshot_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT spine_integrations_id_format_chk CHECK (spine_id ~ '^SPINE-[0-9]{4}$')
);

CREATE TABLE IF NOT EXISTS maroon_core.council_authority_matrix (
  authority_id TEXT PRIMARY KEY,
  domain TEXT NOT NULL,
  gate_condition TEXT NOT NULL,
  required_approver TEXT NOT NULL,
  approval_artifact TEXT,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT council_authority_id_format_chk CHECK (authority_id ~ '^CA-[0-9]{4}$')
);

-- Expansion tables to support artifact lineage and commercial decisions.
CREATE TABLE IF NOT EXISTS maroon_core.artifact_registry (
  artifact_id TEXT PRIMARY KEY,
  artifact_type TEXT NOT NULL,
  artifact_hash TEXT NOT NULL,
  source_lineage JSONB NOT NULL DEFAULT '[]'::jsonb,
  model_used TEXT,
  cost_breakdown_usd NUMERIC(14,4),
  credits_used NUMERIC(14,4),
  storage_uri TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.lineage_edges (
  edge_id BIGSERIAL PRIMARY KEY,
  from_entity TEXT NOT NULL,
  to_entity TEXT NOT NULL,
  relation_type TEXT NOT NULL,
  evidence_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT lineage_edges_unique UNIQUE (from_entity, to_entity, relation_type)
);

CREATE TABLE IF NOT EXISTS maroon_core.valuation_registry (
  valuation_id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL,
  subject_type TEXT NOT NULL,
  valuation_method TEXT NOT NULL,
  low_usd NUMERIC(16,2),
  base_usd NUMERIC(16,2),
  high_usd NUMERIC(16,2),
  confidence_score NUMERIC(5,2),
  notes TEXT,
  approved_by TEXT,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.complete_picture_runs (
  run_id TEXT PRIMARY KEY,
  generated_at TIMESTAMPTZ NOT NULL,
  systems_total INTEGER,
  systems_after_compression INTEGER,
  systems_before INTEGER,
  structural_review_count INTEGER,
  invention_candidates_count INTEGER,
  deep_theme_count INTEGER,
  artifact_count INTEGER,
  alignment_score NUMERIC(8,2),
  open_gap_ids TEXT,
  source_snapshot_uri TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.complete_picture_system_registry (
  system_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  system_type TEXT,
  ontology_layer TEXT,
  pillar_id TEXT,
  module_id TEXT,
  submodule_id TEXT,
  confidence_score INTEGER,
  source_count INTEGER,
  deep_signal_score INTEGER,
  strategic_score INTEGER,
  structural_review BOOLEAN,
  recommended_commercial_action TEXT,
  readiness_stage TEXT,
  value_band_usd TEXT,
  monetization_path TEXT,
  signals TEXT,
  next_action TEXT,
  evidence_refs TEXT,
  origin TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.execution_tickets (
  ticket_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  system_id TEXT,
  system_name TEXT,
  theme_id TEXT,
  theme_title TEXT,
  pillar_id TEXT,
  module_id TEXT,
  priority TEXT,
  status TEXT,
  owner TEXT,
  target_date DATE,
  recommended_commercial_action TEXT,
  readiness_stage TEXT,
  strategic_score INTEGER,
  deep_theme_score INTEGER,
  value_band_usd TEXT,
  objective TEXT,
  kpi TEXT,
  next_action TEXT,
  evidence_refs TEXT,
  runbook_path TEXT,
  push_status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.counsel_ip_queue (
  queue_id TEXT PRIMARY KEY,
  ip_id TEXT NOT NULL,
  invention_id TEXT,
  invention_title TEXT,
  asset_type TEXT,
  jurisdiction TEXT,
  current_filing_status TEXT,
  counsel_status TEXT,
  evidence_bundle_status TEXT,
  deadline DATE,
  days_to_deadline INTEGER,
  priority TEXT,
  queue_status TEXT,
  risk_level TEXT,
  required_counsel_action TEXT,
  required_engineering_action TEXT,
  trust_relevance TEXT,
  owner TEXT,
  target_counsel_date DATE,
  last_updated_utc TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.asset_ownership_registry (
  asset_id TEXT PRIMARY KEY,
  asset_category TEXT NOT NULL,
  asset_name TEXT,
  owner TEXT NOT NULL,
  owner_source TEXT,
  ownership_classification TEXT,
  ip_position TEXT,
  protection_level TEXT,
  disclosure_policy TEXT,
  primary_system_id TEXT,
  pillar_id TEXT,
  module_id TEXT,
  commercialization_action TEXT,
  readiness_stage TEXT,
  source_ref TEXT,
  lineage_hash TEXT,
  last_verified_utc TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.corpus_file_inventory (
  doc_id TEXT PRIMARY KEY,
  source_path TEXT NOT NULL,
  bytes BIGINT NOT NULL,
  mtime_utc TIMESTAMPTZ,
  extension TEXT,
  is_text BOOLEAN,
  priority_weight INTEGER,
  source_tags TEXT,
  scope_class TEXT,
  line_count INTEGER,
  line_scan_status TEXT,
  dedupe_hash TEXT,
  duplicate_group_size INTEGER,
  quality_score NUMERIC(6,2),
  gap_flags TEXT,
  last_scanned_utc TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.corpus_gap_register (
  gap_id TEXT PRIMARY KEY,
  severity TEXT NOT NULL,
  gap_type TEXT NOT NULL,
  source_path TEXT,
  detail TEXT,
  recommended_action TEXT,
  status TEXT,
  created_at_utc TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.corpus_quality_snapshots (
  run_id TEXT PRIMARY KEY,
  generated_at TIMESTAMPTZ NOT NULL,
  docs_total INTEGER,
  text_docs_total INTEGER,
  core_docs_total INTEGER,
  core_text_docs_total INTEGER,
  priority_docs_total INTEGER,
  priority_text_docs_total INTEGER,
  line_coverage_pct NUMERIC(6,2),
  core_line_coverage_pct NUMERIC(6,2),
  priority_line_coverage_pct NUMERIC(6,2),
  duplicate_groups_total INTEGER,
  duplicate_docs_total INTEGER,
  critical_missing_total INTEGER,
  open_gaps_total INTEGER,
  avg_quality_score NUMERIC(6,2),
  core_avg_quality_score NUMERIC(6,2),
  priority_line_fallback_scans_used INTEGER,
  scan_state_complete BOOLEAN,
  scan_state_processed INTEGER,
  scan_state_candidates_total INTEGER,
  summary_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maroon_core.phase_readiness_gate (
  generated_at TIMESTAMPTZ,
  recommended_stage TEXT,
  readiness_level TEXT,
  metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
  hard_blockers JSONB NOT NULL DEFAULT '[]'::jsonb,
  warnings JSONB NOT NULL DEFAULT '[]'::jsonb,
  forensic_health_status TEXT,
  run_id TEXT,
  operator_directive TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS inventions_owner_idx
  ON maroon_core.inventions (owner, updated_at DESC);
CREATE INDEX IF NOT EXISTS inventions_priority_idx
  ON maroon_core.inventions (priority);
CREATE INDEX IF NOT EXISTS ip_assets_owner_idx
  ON maroon_core.ip_assets (owner, updated_at DESC);
CREATE INDEX IF NOT EXISTS ip_assets_linked_invention_idx
  ON maroon_core.ip_assets (linked_invention_id);
CREATE INDEX IF NOT EXISTS inventions_registry_mirror_stage_idx
  ON maroon_core.inventions_registry_mirror (stage, owner);
CREATE INDEX IF NOT EXISTS ip_registry_mirror_status_idx
  ON maroon_core.ip_registry_mirror (filing_status, owner);
CREATE INDEX IF NOT EXISTS invention_sync_audit_target_idx
  ON maroon_core.invention_sync_audit (target, synced_at DESC);
CREATE INDEX IF NOT EXISTS budget_items_owner_idx
  ON maroon_core.budget_items (owner, updated_at DESC);
CREATE INDEX IF NOT EXISTS decision_records_date_idx
  ON maroon_core.decision_records (date DESC);
CREATE INDEX IF NOT EXISTS spine_integrations_layer_idx
  ON maroon_core.spine_integrations (layer, sync_state);
CREATE INDEX IF NOT EXISTS council_authority_status_idx
  ON maroon_core.council_authority_matrix (status);
CREATE INDEX IF NOT EXISTS artifact_registry_type_idx
  ON maroon_core.artifact_registry (artifact_type, created_at DESC);
CREATE INDEX IF NOT EXISTS lineage_edges_from_idx
  ON maroon_core.lineage_edges (from_entity);
CREATE INDEX IF NOT EXISTS lineage_edges_to_idx
  ON maroon_core.lineage_edges (to_entity);
CREATE INDEX IF NOT EXISTS complete_picture_registry_action_idx
  ON maroon_core.complete_picture_system_registry (pillar_id, recommended_commercial_action);
CREATE INDEX IF NOT EXISTS execution_tickets_priority_status_idx
  ON maroon_core.execution_tickets (priority, status);
CREATE INDEX IF NOT EXISTS counsel_ip_queue_priority_status_idx
  ON maroon_core.counsel_ip_queue (priority, queue_status);
CREATE INDEX IF NOT EXISTS asset_ownership_category_owner_idx
  ON maroon_core.asset_ownership_registry (asset_category, owner);
CREATE INDEX IF NOT EXISTS corpus_inventory_text_priority_idx
  ON maroon_core.corpus_file_inventory (is_text, priority_weight, line_scan_status);
CREATE INDEX IF NOT EXISTS corpus_gap_severity_type_idx
  ON maroon_core.corpus_gap_register (severity, gap_type);
CREATE INDEX IF NOT EXISTS corpus_quality_generated_idx
  ON maroon_core.corpus_quality_snapshots (generated_at DESC);
CREATE INDEX IF NOT EXISTS phase_readiness_generated_idx
  ON maroon_core.phase_readiness_gate (generated_at DESC);

CREATE OR REPLACE VIEW maroon_core.corpus_quality_overview AS
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
  (SELECT COUNT(*) FROM maroon_core.corpus_file_inventory) AS inventory_rows,
  (SELECT COUNT(*) FROM maroon_core.corpus_gap_register) AS gap_rows,
  NOW() AS refreshed_at
FROM maroon_core.corpus_quality_snapshots AS snapshot
ORDER BY snapshot.generated_at DESC, snapshot.run_id DESC
LIMIT 1;

CREATE OR REPLACE VIEW maroon_core.executive_data_plane_overview AS
SELECT
  (SELECT COUNT(*) FROM maroon_core.inventions) AS inventions_count,
  (SELECT COUNT(*) FROM maroon_core.ip_assets) AS ip_assets_count,
  (SELECT COUNT(*) FROM maroon_core.budget_items) AS budget_items_count,
  (SELECT COUNT(*) FROM maroon_core.decision_records) AS decision_records_count,
  (SELECT COUNT(*) FROM maroon_core.spine_integrations) AS spine_integrations_count,
  (SELECT COUNT(*) FROM maroon_core.council_authority_matrix) AS authority_rules_count,
  (SELECT COUNT(*) FROM maroon_core.artifact_registry) AS artifacts_count,
  (SELECT COUNT(*) FROM maroon_core.counsel_ip_queue) AS counsel_queue_count,
  (SELECT COUNT(*) FROM maroon_core.asset_ownership_registry) AS ownership_registry_count,
  (SELECT COUNT(*) FROM maroon_core.phase_readiness_gate) AS phase_gate_snapshot_count,
  (SELECT COUNT(*) FROM maroon_core.corpus_file_inventory) AS corpus_inventory_count,
  (SELECT COUNT(*) FROM maroon_core.corpus_gap_register) AS corpus_gap_count,
  (SELECT AVG(quality_score) FROM maroon_core.corpus_file_inventory) AS corpus_avg_quality_score,
  NOW() AS refreshed_at;

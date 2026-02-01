# Maroon Corpus Consolidation Strategy

## Executive Summary

The Maroon Empire operates on **corpus**, not data. Corpus is structured, verified, and defensible information that drives operational decisions across all five entities (Tech, Foods, Law, Consulting, GPT).

**Current State**: 130 analysis_outputs files exist but are **empty** (0 bytes) - representing a critical gap in corpus documentation.

---

## Corpus Taxonomy

### 1. Regulatory Corpus

**Purpose**: Legal and compliance signals  
**Sources**: WSDA, USDA, WIC/EBT regulations, SB 5605  
**Ontology Level**: Signal → Pattern  
**Status**: Needs population

**Key Documents** (currently empty):

- Federal and state WIC EBT rule excerpts.md
- RMP and hot-foods EBT feasibility for WA_AK.md
- Recent SNAP_EBT updates shaping delivery rules.md
- Sweets EBT ban update.md

### 2. Patent Corpus

**Purpose**: IP landscape and claim analysis  
**Sources**: USPTO, Google Patents, competitor filings  
**Ontology Level**: Signal → Pattern → Protocol  
**Status**: Needs population

**Key Documents** (currently empty):

- Patent Landscape and Counsel Prep.md
- Claim-overlap matrix for core Maroon-Tech inventions.md
- Competitor Patent Crosswalk: Grocery, AI, Data Fusion.md
- TruthTeller Patent Draft.md
- Finalized EBT patent claim set.md

### 3. Market Corpus

**Purpose**: Business intelligence and opportunity analysis  
**Sources**: BCG Matrix, Zillow API, food desert maps  
**Ontology Level**: Signal → Pattern  
**Status**: Needs population

**Key Documents** (currently empty):

- EBT Expansion Sites: Chicago and Memphis.md
- EBT Expansion: First-Cut Food-Desert Map.md
- Tacoma EBT Priority Site Shortlist.md
- Live EBT-Friendly Property Alerts.md

### 4. Financial Corpus

**Purpose**: Budget tracking, ROI analysis, grant opportunities  
**Sources**: GCP billing, AWS costs, grant databases  
**Ontology Level**: Signal → Pattern → Protocol  
**Status**: Partially populated

**Key Documents**:

- FINANCIAL_LEDGER.md (populated)
- EBT Commissary & Fleet DSCR Model.md (empty)
- EBT commissary ROI & DSCR snapshot.md (empty)
- Valuation Anchors for Commissary + EBT Marketplace.md (empty)

### 5. Architectural Corpus

**Purpose**: System design and technical specifications  
**Sources**: Internal design docs, engineering guidelines  
**Ontology Level**: Protocol → Ontology  
**Status**: Partially populated

**Key Documents**:

- MASTER_ONTOLOGY.md (populated)
- DATABASE_SCHEMA.md (populated)
- Maroon Enterprise Schema.md (empty)
- Truth Layer Architecture.md (empty)
- Maroon Orchestrator Overview.md (empty)

### 6. Philosophical Corpus

**Purpose**: Core principles and operational doctrine  
**Sources**: Creative Charter, Canon Principles  
**Ontology Level**: Ontology (governance)  
**Status**: Needs population

**Key Documents** (currently empty):

- Maroon.md Creative Charter.md
- Maroon Canon Principles.md
- Maroon.md Design Doctrine.md
- Maroon Omega Protocol.md

---

## Missing Patterns & Systems

### Identified Gaps

1. **Evaluation Framework**: No systematic evaluation corpus for MVPs
2. **Integration Protocols**: Missing corpus on VM partnerships and integrations
3. **Corpus Metadata**: No tracking of corpus source, verification status, or integrity scores
4. **Iterative Learning**: No mechanism for 100,000x corpus review and pattern enhancement
5. **Money Tracking**: Incomplete financial corpus (GCP credits, AWS status unclear)

### Required Systems

1. **Corpus Ingestion Pipeline**
   - Automated ingestion from APIs (Zillow, WSDA, USPTO)
   - Verification and integrity scoring (Truth Teller)
   - Metadata tagging (source, timestamp, ontology level)
   - Storage in BigQuery with partitioning

2. **Corpus Verification System**
   - Truth Teller integrity scoring
   - Cross-reference validation
   - Human review workflow
   - Version control and audit trail

3. **Corpus Analysis Engine**
   - Pattern recognition (Gemini 1.5 Pro)
   - Gap identification
   - Ontology mapping
   - Predictive modeling

4. **Corpus Distribution System**
   - API endpoints for corpus access
   - GitHub integration for version control
   - Google Drive sync for collaboration
   - Copilot integration for development

---

## Terminology Migration: Data → Corpus

### Files Requiring Updates

1. **DATABASE_SCHEMA.md**
   - Line 3: "shared data ontology" → "shared corpus ontology"
   - Line 14: "Raw signal data" → "Raw signal corpus"
   - Line 47: "CLEAN datasets" → "CLEAN corpus sets"

2. **GCP_STARTUP_APPLICATION.md**
   - Line 13: "data signals" → "corpus signals"

3. **All analysis_outputs files**: Ensure "corpus" terminology when populated

---

## Population Strategy

### Phase 1: Critical Corpus (Immediate)

Populate the 20 most critical documents for MVP deployment:

1. Truth Teller Patent Draft.md
2. Finalized EBT patent claim set.md
3. EBT Commissary & Fleet DSCR Model.md
4. Maroon.md Creative Charter.md
5. Truth Layer Architecture.md

### Phase 2: Business Corpus (Week 1)

Populate financial and market analysis documents:

1. All EBT expansion and site selection docs
2. Grant deadline and funding opportunity docs
3. ROI and valuation documents
4. Patent valuation and licensing docs

### Phase 3: Regulatory Corpus (Week 2)

Populate all regulatory and compliance documents:

1. WIC/EBT rule excerpts
2. SNAP update tracking
3. State-specific regulations (WA, AK, GA, etc.)

### Phase 4: Architectural Corpus (Week 3)

Populate all system design and technical docs:

1. Maroon Enterprise Schema
2. Orchestrator Overview
3. Integration protocols
4. VM partnership documentation

### Phase 5: Philosophical Corpus (Week 4)

Populate all governance and principle documents:

1. Creative Charter
2. Canon Principles
3. Design Doctrine
4. Omega Protocol

---

## Iterative Enhancement Protocol

### The 100,000x Review Cycle

Inspired by IBM, Google, and Palantir's corpus analysis methodologies:

1. **First Pass**: Populate empty files with initial corpus
2. **Second Pass**: Identify missing patterns and cross-references
3. **Third Pass**: Enhance with predictive insights (Truth Teller)
4. **Nth Pass**: Continuous refinement based on new signals

**Automation Strategy**:

- Use Gemini 1.5 Pro for pattern recognition
- Deploy Vertex AI agents for gap identification
- Implement BigQuery for corpus querying
- Enable GitHub Actions for automated verification

---

## Integration with Maroon Systems

### Truth Teller Integration

- Assign integrity scores to all corpus
- Flag low-confidence corpus for human review
- Track corpus provenance and verification chain

### BigQuery Integration

- Store all corpus in partitioned datasets
- Enable SQL querying for pattern analysis
- Mirror clean corpus for LLM-agentic access

### GitHub Copilot Integration

- Reference corpus in code comments
- Enforce corpus terminology in development
- Link code to specific corpus sources

### Google Drive Integration

- Cloud-only corpus access (no local copies)
- Automated backup and versioning
- Collaborative editing with verification workflow

---

## Success Metrics

1. **Corpus Population**: 130/130 files populated (currently 0/130)
2. **Terminology Compliance**: 100% "corpus" usage (zero "data" references)
3. **Integrity Scores**: All corpus verified by Truth Teller
4. **Ontology Mapping**: Every corpus document mapped to ontology level
5. **API Access**: All corpus accessible via cloud APIs
6. **Version Control**: All corpus tracked in GitHub with full history

---

## Next Actions

1. ✅ Create MAROON.md master document
2. ✅ Create CORPUS_CONSOLIDATION.md (this document)
3. ⏳ Update DATABASE_SCHEMA.md terminology
4. ⏳ Update MASTER_ONTOLOGY.md terminology
5. ⏳ Populate Phase 1 critical corpus (20 documents)
6. ⏳ Deploy corpus ingestion pipeline to GCP
7. ⏳ Enable Truth Teller integrity scoring
8. ⏳ Push Maroon-Core to GitHub
9. ⏳ Configure Copilot integration

---

*Corpus is truth. Truth is sovereignty.*

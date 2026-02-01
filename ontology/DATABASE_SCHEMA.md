# Maroon-Core: Truth Teller Database Schema

This schema defines the "Signal Ingestion" and "Integrity Mapping" layer for the Maroon Trust. It connects all businesses (Food, Law, Tech) through a shared data ontology.

## 1. Core Tables

### `signals`

Stores raw ingestion from external APIs (Zillow, WSDA, SEC, etc.)

- `id`: UUID (Primary Key)
- `source`: String (e.g., "WSDA_REGS")
- `entity_id`: String (Foreign Key to local entity)
- `payload`: JSONB (Raw signal data)
- `timestamp`: DateTime
- `integrity_score`: Float (Calculated by Truth Teller)

### `entities`

Master list of people, businesses, and assets in the Maroon network.

- `id`: UUID (Primary Key)
- `type`: Enum (Person, Business, Patent, Asset)
- `name`: String
- `location_coordinates`: Geography (Point)
- `associated_tags`: Array[String] (e.g., ["Commissary", "WIC_Eligible"])

### `predictions`

Output from the Truth Teller engine.

- `id`: UUID (Primary Key)
- `target_id`: UUID (Foreign Key to Entities)
- `logic_model`: String (e.g., "BCG_Matrix_V1")
- `outcome_forecast`: JSONB
- `confidence_level`: Float
- `status`: Enum (Active, Realized, Obsolete)

## 2. Cross-Business Queries (The "Lines")

- **Maroon Foods -> Maroon Law**: Query `signals` for regulatory changes (SB 5605) to trigger `Maroon Law` onboarding SOPs.
- **Maroon Tech -> Onitas Market**: Query `predictions` for market entry points based on localized `entity` analysis.

## 3. Implementation (GCP BigQuery)

- Datasets will be partitioned by `entity_type` and `source`.
- CLEAN datasets will be mirrored for LLM-agentic querying via Vertex AI.

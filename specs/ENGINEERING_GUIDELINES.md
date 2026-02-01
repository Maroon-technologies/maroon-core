# Maroon-Core: Engineering Guidelines (The Maroon.md Standard)

All MVPs must be PRODUCTION-GRADE. We do not build prototypes; we build assets.

## 1. UI/UX Principles (The "Wired" Look)

- **Aesthetic**: Premium, dark-mode default, glassmorphism, accent colors (Maroon/Gold/Sovereign Slate).
- **Typography**: Inter/Outfit for modern, high-readability interfaces.
- **Micro-interactions**: Use Framer Motion/CSS animations for every state change.
- **Mimicry**: Study top-tier apps via YouTube/Dribbble. If it looks "AI-generated," it is failing.

## 2. The Akim Handoff Protocol

Every MVP must include:

1. **Engineering Packet**: Architectural diagrams and API definitions.
2. **Sovereign Logic**: All business rules (EBT Split, Law Onboarding) must be in standard JSON/MD formats.
3. **Traceability**: Link every feature back to the `MASTER_ONTOLOGY.md`.

## 3. Tech Stack Requirements

- **Frontend**: Vite + React/TS (for speed and premium feel).
- **Backend**: Python (FastAPI) or Go (for sovereign compute).
- **Database**: PostgreSQL (local) mirrored to BigQuery (cloud).
- **Notifications**: Native SMS/Email integration (Twilio/SendGrid).

## 4. Documentation

Every repo must have a `MAROON_SOVEREIGNTY.md` explaining the "Why" and the "How" for future engineers.

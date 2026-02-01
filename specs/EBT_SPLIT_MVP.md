# Maroon-Core Specs: EBT SPLIT

## Overview: Transaction Split Apparatus

The EBT Split apparatus is a proprietary payment processing logic (Patent Pending) designed to seamlessly handle "split transactions" where EBT/WIC eligible items are separated from non-eligible items at the point of sale, specifically within the Onitas Market ecosystem.

## Core Apparatus (Patent Pending)

1. **Real-time Classification**: Identifying eligible items (WIC/EBT) based on the "Nanny" regulatory database.
2. **Transaction Forking**: Mirroring single user actions into dual-stream payment gateways.
3. **Receipt Reconciliation**: Producing sovereign, unified receipts that comply with state food-access audits.

## Technical Requirements

- Integration with major EBT/WIC processors.
- High-integrity auditing for Maroon Law "Deflection" protocols.

## Engineering Directives (for Akim)

- Priority: 1 (Critical for Onitas Market Launch).
- Must handle 10k+ SKU classifications in <200ms.

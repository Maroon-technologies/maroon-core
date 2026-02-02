# EBT Split Apparatus - Google Sheets Financial Model

## ROI Calculator & Valuation Analysis

> **Note**: This document describes the Google Sheets structure. Actual Google Sheets will be created and shared separately.

---

## Sheet 1: Revenue Projections

### Column Structure

| Year | Transactions | Revenue/Txn | Total Revenue | COGS | Gross Profit | OpEx | Net Profit |
|------|-------------|-------------|---------------|------|--------------|------|------------|
| 2026 | 126,000 | $0.15 | $18,900 | $3,780 | $15,120 | $30,000 | -$14,880 |
| 2027 | 1,260,000 | $0.15 | $189,000 | $37,800 | $151,200 | $150,000 | $1,200 |
| 2028 | 12,600,000 | $0.12 | $1,512,000 | $302,400 | $1,209,600 | $500,000 | $709,600 |
| 2029 | 63,000,000 | $0.10 | $6,300,000 | $1,260,000 | $5,040,000 | $1,200,000 | $3,840,000 |
| 2030 | 126,000,000 | $0.10 | $126,00,000 | $2,520,000 | $10,080,000 | $2,000,000 | $8,080,000 |

### Formulas (Google Sheets)

```
=B2*C2  // Total Revenue
=D2*0.2  // COGS (20% of revenue)
=D2-E2  // Gross Profit
=G2-F2  // Net Profit
```

---

## Sheet 2: Valuation Models

### Methodology Comparison

| Valuation Method | Multiple | Calculation | Result |
|------------------|----------|-------------|--------|
| Revenue Multiple | 5x ARR | $12.6M × 5 | **$63M** |
| EBITDA Multiple | 15x | $8.08M × 15 | **$121.2M** |
| Comparable Sales | Average | (Stripe/Square deals) | **$85M** |
| DCF Model | WACC 12% | NPV of 10-year cash flows | **$147M** |

**Conservative**: $50M  
**Realistic**: $85M  
**Optimistic**: $150M

---

## Sheet 3: Customer Acquisition Cost (CAC)

| Channel | Cost/Customer | Customers | Total CAC |
|---------|--------------|-----------|-----------|
| Walmart Direct | $0 (B2B deal) | 50M | $0 |
| Square Partnership | $5,000 (integration) | 100K stores | $5,000 |
| Independent Stores | $100 (marketing) | 10K | $1,000,000 |

**Total CAC**: $1,005,000  
**Customer Lifetime Value (LTV)**: $500/customer  
**LTV/CAC Ratio**: 500:1 (excellent)

---

## Sheet 4: Competitor Analysis

| Company | Valuation | Revenue | Revenue Multiple |
|---------|-----------|---------|------------------|
| Stripe | $95B | $14B | 6.8x |
| Square | $44B | $17.5B | 2.5x |
| PayPal | $75B | $29B | 2.6x |
| **Maroon (our projection)** | **$85M** | **$12.6M** | **6.7x** |

---

## Sheet 5: Investment Scenarios

### Seed Round (Now)

- **Raise**: $500K
- **Valuation**: $3M pre-money
- **Dilution**: 14.3%
- **Use of funds**:
  - Engineering: $250K
  - Pilot programs: $100K
  - Legal (patents): $50K
  - Sales: $100K

### Series A (Year 2)

- **Raise**: $5M
- **Valuation**: $25M pre-money
- **Dilution**: 16.7%
- **Use of funds**:
  - Scale engineering: $2M
  - National sales: $2M
  - Operations: $1M

### Exit (Year 3-5)

- **Acquirer**: Visa, Mastercard, or Stripe
- **Exit valuation**: $150M-$500M
- **Return to seed investors**: 50x-166x

---

## Sheet 6: Cost Breakdown (Build)

### Development Costs

| Phase | Duration | Team Size | Cost/Month | Total |
|-------|----------|-----------|------------|-------|
| Prototype | 3 months | 2 engineers | $20K | $60K |
| MVP | 6 months | 5 engineers | $50K | $300K |
| Production | 12 months | 10 engineers | $100K | $1.2M |

**Total Development**: $1.56M

### Infrastructure Costs (AWS)

| Scale Level | Transactions/Day | AWS Cost/Month | Annual |
|-------------|------------------|----------------|--------|
| Pilot | 1,000 | $70 | $840 |
| Growth | 100,000 | $2,050 | $24,600 |
| Scale | 1,000,000 | $20,500 | $246,000 |

---

## Sheet 7: Market Size (TAM/SAM/SOM)

### Total Addressable Market (TAM)

- **EBT cardholders**: 42 million Americans
- **Transactions/year**: 1.26 billion
- **Potential revenue** @ $0.10/txn: **$126M/year**

### Serviceable Available Market (SAM)

- **Online + modern POS only**: 50% of transactions
- **Potential revenue**: **$63M/year**

### Serviceable Obtainable Market (SOM - Year 5)

- **Market share**: 10% (realistic)
- **Revenue**: **$12.6M/year**

---

## Sheet 8: Sensitivity Analysis

### Revenue Impact

| Variable | -20% | Base | +20% |
|----------|------|------|------|
| Price/txn | $10.08M | $12.6M | $15.12M |
| Conversion | $10.08M | $12.6M | $15.12M |
| Market size | $10.08M | $12.6M | $15.12M |

### Valuation Impact

| Revenue Multiple | 4x | 5x | 6x | 7x |
|------------------|-----|-----|-----|-----|
| Valuation | $50.4M | $63M | $75.6M | $88.2M |

---

## Sheet 9: Break-Even Analysis

### Fixed Costs (Monthly)

- Engineering: $100K
- AWS: $20K
- Office/Admin: $10K
- Sales: $20K
- **Total**: $150K/month

### Variable Costs (Per Transaction)

- AWS compute: $0.02
- Payment processing: $0.03
- **Total**: $0.05/txn

### Break-Even Calculation

```
Monthly transactions needed:
$150,000 / ($0.15 - $0.05) = 1,500,000 transactions/month
= 50,000 transactions/day
```

**Achieve break-even**: Month 9 (with 3 major grocery chains)

---

## Sheet 10: Dashboard (Summary)

### Key Metrics (Auto-calculated)

| Metric | Value | Status |
|--------|-------|--------|
| Current Valuation | $85M | ✅ Strong |
| 5-Year Revenue | $12.6M | ✅ On track |
| Gross Margin | 80% | ✅ Excellent |
| Break-Even Month | Month 9 | ✅ Achievable |
| LTV/CAC Ratio | 500:1 | ✅ Outstanding |
| Market Share (Year 5) | 10% | ✅ Realistic |

### Charts (to be created in Google Sheets)

1. Revenue Growth (line chart)
2. Customer Acquisition (bar chart)
3. Valuation Scenarios (waterfall chart)
4. Market Share Pizza (pie chart)

---

## How to Use This Google Sheet

### For Investors

1. Go to "Dashboard" tab
2. Review key metrics
3. Adjust assumptions in "Sensitivity Analysis"
4. See impact on valuation

### For Maroon Trust

1. Review "Valuation Models" for IP value
2. Check "Investment Scenarios" for funding needs
3. Use "Cost Breakdown" for budget planning

### For Engineers

1. See "Cost Breakdown" for development budget
2. Review "Infrastructure Costs" for AWS planning

---

**Google Sheets Link**: [Will be created and shared]  
**Last Updated**: 2026-02-01  
**Owner**: Maroon Technologies Financial Team

---

*This document describes the structure. Actual interactive Google Sheets with formulas, charts, and scenario planning will be created separately.*

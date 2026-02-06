# Supply AM Queries

Queries for Supply Account Management metrics (Ashton's team).

## Terminology

**NPR (Net Payout Retention)** is used for suppliers, not NRR:
- **NPR** = Supplier perspective - did they get paid more?
- **NRR** = Customer perspective - did they spend more?

This distinction clarifies what each metric measures.

## Queries

| File | Metric | Owner | Target | Status |
|------|--------|-------|--------|--------|
| `supply-npr-summary-by-year.sql` | NPR Summary (P&L Match) | Ashton | — | ✅ Created |
| `supply-npr-by-supplier.sql` | NPR by Supplier (with Unlinked) | Ashton | — | ✅ Created |
| `core-action-state-counts.sql` | Active/Loosing/Lost Counts | Ashton | — | ✅ Created |
| `nrr-top-supply-users-financial.sql` | NPR Top Supply Users (Financial) | Ashton | 110% | ✅ Updated |
| `nrr-top-supply-users.sql` | NRR Top Supply Users (Offer-Based) | Ashton | 110% | ✅ Legacy |

## Key Changes (2026-02-05)

### P&L Matching
- **All queries now match QBO P&L exactly** by including "Unlinked (Not in Platform)" row
- Previously excluded unlinked bills → totals didn't match P&L
- Now totals tie out exactly to QBO accounts 4200-4230

### Terminology Update
- Renamed **NRR** to **NPR** (Net Payout Retention) for supply-side queries
- Clarifies that we're measuring supplier payouts, not customer revenue

### New Views for BigQuery
- `Supplier_Development` - Mirrors customer_development with Core Action State
- `cohort_payout_retention_matrix_by_supplier` - Supplier payout waterfall by cohort

## Query Descriptions

### `supply-npr-summary-by-year.sql` ⭐ NEW
P&L-matched yearly summary of supplier payouts:
- Gross Bills, Vendor Credits, Net Payouts by year
- NPR % vs prior year
- **Totals match QBO P&L exactly**

### `supply-npr-by-supplier.sql` ⭐ NEW
Supplier-level detail with:
- "Unlinked (Not in Platform)" row for unattributed bills
- "TOTAL (P&L Match)" row for validation
- NPR by year for each supplier
- Includes all suppliers regardless of linkage

### `core-action-state-counts.sql` ⭐ NEW
Dashboard metrics for supplier health:
- **Active**: Has payouts in 2025, stable or growing
- **Loosing**: Has payouts but declining >50% YoY
- **Lost**: Had payouts in 2024, none in 2025
- **Inactive**: No recent activity

### `nrr-top-supply-users-financial.sql` (Updated)
- Now uses NPR terminology
- Includes "Unlinked (Not in Platform)" row
- Column names changed: `rev_YYYY` → `payout_YYYY`
- Still recommended for supplier-level analysis

### `nrr-top-supply-users.sql` (Legacy)
- Simple offer-based query using Supplier_Metrics view
- Does NOT include vendor credits
- Kept for historical reference

## Data Sources

### Financial-Based Queries
- **bill** (`src_fivetran_qbo.bill`) - QBO bills with transaction dates
- **bill_line** (`src_fivetran_qbo.bill_line`) - Bill line items with account attribution
- **vendor_credit** (`src_fivetran_qbo.vendor_credit`) - Refunds/adjustments
- **vendor_credit_line** (`src_fivetran_qbo.vendor_credit_line`) - Credit line items
- **account** (`src_fivetran_qbo.account`) - Account definitions (filter to payout accounts)
- **remittance_line_items** (`mongodb.remittance_line_items`) - Links bill_number to supplier org

### Offer-Based Query
- **Supplier_Metrics** (`App_KPI_Dashboard.Supplier_Metrics`) - Aggregated supplier GMV, payouts, samples by year

## QBO Payout Accounts

| Account # | Name |
|-----------|------|
| 4200 | Event Organizer Fee |
| 4210 | Sampling Payouts |
| 4220 | Sponsorship Payouts |
| 4230 | Activation Payouts |

## Bill Linkage Quality

**After Split Bill Fix (2026-02-05):**

| Year | QBO Bills | Linked | Linkage % |
|------|-----------|--------|-----------|
| 2026 | 39 | 39 | **100.0%** |
| 2025 | 4,917 | 4,897 | **99.6%** |
| 2024 | 4,351 | 4,143 | **95.2%** |
| 2023 | 5,864 | 4,892 | **83.4%** |

**Split Bill Handling:** Bills with `_2`, `_3`, `_4` suffixes are linked to their primary bill's supplier org using `REGEXP_REPLACE(doc_number, r'_\d+$', '')`.

## P&L Reconciliation (2025)

| Metric | Amount | Notes |
|--------|--------|-------|
| **QBO P&L Total (4200-4230)** | $4,045,628 | All payout account activity |
| **Linked to Platform** | $4,032,340 | 99.7% of $ linked |
| **Unlinked (Not in Platform)** | $13,288 | Included as separate row |
| **Query Total** | $4,045,628 | **Matches P&L exactly** |

## NPR Methodology

### Formula
```
Supply NPR = (Current Year Net Payouts) / (Prior Year Net Payouts) * 100

Where:
- Net Payouts = Bills - Vendor Credits (both in payout accounts 4200-4230)
- Timing = QBO transaction_date (when money moved)
```

### Core Action State Logic
```sql
CASE
  WHEN payout_2025 > 0 AND payout_2024 > 0 THEN
    CASE WHEN (payout_2024 - payout_2025) / payout_2024 > 0.50
         THEN 'loosing' ELSE 'active' END
  WHEN payout_2025 > 0 THEN 'active'    -- New or reactivated
  WHEN payout_2024 > 0 THEN 'lost'      -- Churned
  ELSE 'inactive'                        -- Dormant
END
```

## Related BigQuery Views

| View Name | Location | Purpose |
|-----------|----------|---------|
| `Supplier_Development` | `App_KPI_Dashboard` | Supplier-level metrics with Core Action State |
| `cohort_payout_retention_matrix_by_supplier` | `App_KPI_Dashboard` | Payout waterfall by cohort |

## Usage

### P&L Validation
```sql
-- Run supply-npr-summary-by-year.sql
-- 2025 net_payouts should equal $4,045,628
```

### Supplier Analysis
```sql
-- Run supply-npr-by-supplier.sql for full detail
-- TOTAL row should match P&L
-- Unlinked row shows unattributed $ trend
```

### Dashboard Metrics
```sql
-- Run core-action-state-counts.sql
-- Returns Active/Loosing/Lost counts for dashboard cards
```

# Supply NPR (Net Payout Retention) + Supplier Development View

**Project**: `/Users/deucethevenowworkm1/Projects/company-kpi-dashboard`
**Plan File**: `plans/2026-02-05-supply-npr-implementation.md`

## Goal
Create comprehensive Supply-side metrics that mirror the Demand-side (customer) infrastructure:

1. **Summary Query**: Aggregate Supply NRR by year (matches QBO P&L exactly)
2. **Supplier Detail Query**: NRR by Supplier Name, with unlinked grouped as single row
3. **Supplier Development View**: Like `customer_development` with Core Action State, GMV, Take Rate
4. **Cohort Retention Matrix**: Like the demand-side matrix showing FirstYear cohorts with NRR %
5. **Core Action State Metrics**: Active/Loosing/Lost counts for dashboard display

**Key Changes**:
- Include ALL payout dollars (don't exclude unlinked) so totals match P&L exactly
- Unlinked NRR IS meaningful - shows trend of unlinked $ volume year-over-year
- Build parallel structure to demand-side for consistency

---

## Dashboard Visualization Ideas

| Dashboard | Metric | Visualization |
|-----------|--------|---------------|
| **Supply AM** | NRR $ by Year | Waterfall chart (green/yellow/red) |
| **Supply AM** | Core Action State | Counts: Active / Loosing / Lost |
| **Demand Sales** | Customer NRR % | Waterfall chart (green/yellow/red) |
| **Demand Sales** | Core Action State | Counts: Active / Loosing / Lost |

---

## Terminology Clarification

| Term | Meaning | Source |
|------|---------|--------|
| **Net Revenue** | GMV + Discounts - Credit Memos - Organizer Payout + Vendor Credits | What Recess keeps (matches P&L) |
| **GMV** | Gross Merchandise Value | Total marketplace value generated |
| **Organizer Payout** | Bills - Vendor Credits | What the supplier gets paid |
| **NPR (Net Payout Retention)** | Current year payouts / Prior year payouts | Supplier health metric - are they getting paid more? |
| **Linked** | Bill # found in MongoDB remittance_line_items | Can attribute to supplier org |
| **Unlinked** | Bill # NOT in platform | Grouped as "Unlinked" row |

### Why NPR instead of NRR?
- **NRR (Net Revenue Retention)** = Customer perspective (did customer spend more?)
- **NPR (Net Payout Retention)** = Supplier perspective (did supplier get paid more?)

The supplier waterfall shows **payouts by cohort** - are we keeping suppliers happy and growing their business with us?

### Net Revenue Formula (Full P&L Match)
```
Net Revenue = GMV (invoices 4110-4169)
            + Discounts (4190, typically negative)
            - Credit Memos (4110-4169)
            - Organizer Payouts (bills 4200-4230)
            + Vendor Credits (4200-4230)
```

This matches the Take Rate calculation in `bigquery_client.py:get_take_rate()`.

---

## Supplier Lifecycle States

Suppliers flow through states based on payout activity:

```
Active → Loosing → Lost → Inactive
  ↑                         ↓
  └─────── reactivate ──────┘
```

| State | Definition | Dashboard Card |
|-------|------------|----------------|
| **Active** | Has payouts in current period, stable or growing | 🟢 Healthy suppliers |
| **Loosing** | Has payouts but declining >50% YoY | 🟡 Churning (at risk) |
| **Lost** | Had payouts last year, none this year | 🔴 Churned |
| **Inactive** | No recent payouts, dormant relationship | ⚪ Dormant |

**Dashboard shows current counts** - snapshot of supplier base health, not time-stamped.

---

## Query 1: Summary by Year (P&L Matched)

**Output:**
| Year | Gross Bills | Vendor Credits | Net Payouts | NRR vs Prior Year |
|------|-------------|----------------|-------------|-------------------|
| 2022 | $X | $Y | $Z | — |
| 2023 | ... | ... | ... | XX% |
| 2024 | ... | ... | ... | XX% |
| 2025 | ... | ... | ... | XX% |
| 2026 | ... | ... | ... | XX% (YTD) |

**P&L Validation Row:**
| Source | 2025 Net Payouts |
|--------|------------------|
| QBO P&L (4200-4230) | $4,045,628 |
| This Query | $4,045,628 ✓ |

---

## Query 2: Supplier Detail (with Unlinked Row)

**Output:**
| Supplier Name | Net Payout 2022 | ... | Net Payout 2025 | Net Payout 2026 | Total LTV | NRR 2025 | NRR 2026 |
|---------------|-----------------|-----|-----------------|-----------------|-----------|----------|----------|
| Inspired Consumer | $0 | ... | $338,222 | $X | $1.4M | XX% | XX% |
| WeWork | $106,178 | ... | $46,529 | $X | $792K | XX% | XX% |
| ... | ... | ... | ... | ... | ... | ... | ... |
| **Unlinked** | $X | ... | $1,080 | $X | $X | XX% | XX% |
| **TOTAL** | $X | ... | $4,045,628 | $X | $X | XX% | XX% |

---

## Implementation Changes

### File: `queries/supply-am/nrr-top-supply-users-financial.sql`

**Change 1: Remove exclusion filter (Line 126)**
```sql
-- BEFORE:
WHERE supplier_org_name != 'UNLINKED'  -- Exclude unlinked records

-- AFTER:
-- No WHERE clause - include all records including 'Unlinked'
```

**Change 2: Rename 'UNLINKED' to clearer label**
```sql
-- In bills_with_supplier and credits_with_supplier CTEs:
COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name
```

**Change 3: Ensure threshold doesn't exclude Unlinked**
```sql
-- BEFORE:
WHERE total_ltv >= 10000

-- AFTER:
WHERE total_ltv >= 10000 OR supplier_org_name = 'Unlinked (Not in Platform)'
```

---

## New File: `queries/supply-am/supply-npr-summary-by-year.sql`

Creates the P&L-matched summary view:

```sql
-- Supply NPR Summary by Year (P&L Matched)
-- Matches QBO accounts 4200, 4210, 4220, 4230 exactly

WITH payout_accounts AS (
  SELECT id as account_id, account_number
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),

-- All QBO bills in payout accounts
all_bills AS (
  SELECT
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as gross_bills
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
  GROUP BY 1
),

-- All QBO vendor credits in payout accounts
all_credits AS (
  SELECT
    EXTRACT(YEAR FROM vc.transaction_date) as txn_year,
    SUM(CAST(vcl.amount AS FLOAT64)) as vendor_credits
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE
  GROUP BY 1
),

-- Combine by year
yearly_totals AS (
  SELECT
    COALESCE(b.txn_year, c.txn_year) as year,
    COALESCE(b.gross_bills, 0) as gross_bills,
    COALESCE(c.vendor_credits, 0) as vendor_credits,
    COALESCE(b.gross_bills, 0) - COALESCE(c.vendor_credits, 0) as net_payouts
  FROM all_bills b
  FULL OUTER JOIN all_credits c ON b.txn_year = c.txn_year
)

SELECT
  year,
  ROUND(gross_bills, 2) as gross_bills,
  ROUND(vendor_credits, 2) as vendor_credits,
  ROUND(net_payouts, 2) as net_payouts,
  ROUND(net_payouts / NULLIF(LAG(net_payouts) OVER (ORDER BY year), 0) * 100, 1) as npr_vs_prior_year
FROM yearly_totals
WHERE year >= 2022
ORDER BY year;
```

---

## New File: `queries/supply-am/supply-npr-by-supplier.sql`

Creates the supplier-level detail with Unlinked row:

```sql
-- Supply NPR by Supplier (Financial-Based, P&L Matched)
-- Groups unlinked bills as single "Unlinked (Not in Platform)" row
-- Totals match QBO P&L exactly

WITH payout_accounts AS (...),
remittance_supplier_map AS (...),
qbo_payout_bills AS (...),  -- With split bill handling
qbo_payout_credits AS (...),
bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    ...
),
credits_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    ...
),
all_transactions AS (...),
supplier_yearly_revenue AS (
  SELECT ...
  FROM all_transactions
  -- NO WHERE CLAUSE - includes Unlinked
  GROUP BY supplier_org_name, txn_year
),
supplier_pivot AS (...),
npr_calculation AS (...)

-- Main output with Unlinked row + TOTAL row
SELECT * FROM npr_calculation
WHERE total_ltv >= 10000 OR supplier_org_name = 'Unlinked (Not in Platform)'

UNION ALL

-- Add TOTAL row for P&L validation
SELECT
  'TOTAL (P&L Match)' as supplier_org_name,
  SUM(rev_2022), SUM(rev_2023), SUM(rev_2024), SUM(rev_2025), SUM(rev_2026),
  SUM(total_ltv),
  -- Aggregate NPR calculations
  ROUND(SUM(rev_2023) / NULLIF(SUM(rev_2022), 0) * 100, 1) as npr_2023,
  ...
FROM npr_calculation

ORDER BY CASE
  WHEN supplier_org_name = 'TOTAL (P&L Match)' THEN 1
  WHEN supplier_org_name = 'Unlinked (Not in Platform)' THEN 2
  ELSE 3 END,
total_ltv DESC;
```

---

---

## New View: `Supplier_Development` (like customer_development)

**Location**: `sql/views/supplier-development.sql` → BigQuery view

**Structure** (mirrors customer_development with 3 key metrics):

### Identification
| Column | Type | Description |
|--------|------|-------------|
| `supplier_org_name` | STRING | From remittance or 'Unlinked (Not in Platform)' |
| `core_action_state` | STRING | active / loosing / lost / inactive |
| `first_year` | INT64 | First year with payouts (cohort assignment) |
| `last_payout_date` | DATE | Most recent bill transaction_date |

### Net Revenue (What Recess Keeps)
| Column | Type | Description |
|--------|------|-------------|
| `net_revenue_2022` - `net_revenue_2026` | FLOAT64 | GMV - Organizer Payout per year |
| `total_net_revenue` | FLOAT64 | Lifetime net revenue |

### GMV (Gross Marketplace Value)
| Column | Type | Description |
|--------|------|-------------|
| `gmv_2022` - `gmv_2026` | FLOAT64 | Total GMV per year |
| `total_gmv` | FLOAT64 | Lifetime GMV |

### Organizer Payout (What Supplier Gets Paid)
| Column | Type | Description |
|--------|------|-------------|
| `payout_2022` - `payout_2026` | FLOAT64 | Bills - Vendor Credits per year |
| `total_payout` | FLOAT64 | Lifetime payouts |

### Calculated Metrics
| Column | Type | Description |
|--------|------|-------------|
| `take_rate` | FLOAT64 | Net Revenue / GMV (what % Recess keeps) |
| `npr_2023` - `npr_2026` | FLOAT64 | Net Payout Retention (payout_Y / payout_Y-1) |

**Core Action State Logic** (based on payout activity):
```sql
CASE
  WHEN payout_2025 > 0 AND payout_2024 > 0 THEN
    CASE WHEN (payout_2024 - payout_2025) / payout_2024 > 0.50
         THEN 'loosing' ELSE 'active' END
  WHEN payout_2025 > 0 THEN 'active'  -- New or reactivated in 2025
  WHEN payout_2024 > 0 THEN 'lost'    -- Had 2024, none in 2025
  ELSE 'inactive'                      -- No recent activity (pre-2024)
END as core_action_state
```

**Data Sources:**
- **GMV + Payout**: Join `Supplier_Metrics` (by Supplier_Name) for GMV, use QBO bills for Payouts
- **Net Revenue**: GMV - Payout (calculated)

---

## New View: `cohort_payout_retention_matrix_by_supplier`

**Location**: `sql/views/cohort-payout-retention-matrix-supplier.sql` → BigQuery view

This is the **supplier payout waterfall** showing how much each cohort gets paid over time.

**Output Format** (3 stacked result sets like customer version):

### Chart 1: PAYOUT_DOLLARS (What suppliers received)
| chart | first_year | y2022 | y2023 | y2024 | y2025 | y2026 |
|-------|------------|-------|-------|-------|-------|-------|
| PAYOUT_DOLLARS | 2022 | $X | $Y | $Z | ... | ... |
| PAYOUT_DOLLARS | 2023 | | $X | $Y | ... | ... |
| PAYOUT_DOLLARS | 2024 | | | $X | ... | ... |

### Chart 2: TOTAL (Grand total for P&L validation)
| chart | first_year | y2022 | y2023 | y2024 | y2025 | y2026 |
|-------|------------|-------|-------|-------|-------|-------|
| TOTAL | NULL | $sum | $sum | $sum | $sum | $sum |

### Chart 3: NPR_PERCENT (Net Payout Retention by cohort)
| chart | first_year | y2022 | y2023 | y2024 | y2025 | y2026 |
|-------|------------|-------|-------|-------|-------|-------|
| NPR_PERCENT | 2022 | 100% | 54% | 36% | 31% | 23% |
| NPR_PERCENT | 2023 | | 100% | 77% | 52% | 12% |

**Color Coding for Dashboard Waterfall**:
- 🟢 Green: >= 100% (supplier payouts growing)
- 🟡 Yellow: 50-99% (moderate decline)
- 🔴 Red: < 50% (significant decline)

**Cohort Assignment**:
```sql
-- First year supplier had a payout (bills in 4200-4230 accounts)
first_payout_year AS (
  SELECT
    supplier_org_name,
    MIN(txn_year) as cohort_year
  FROM supplier_yearly_payouts
  WHERE net_payout > 0
  GROUP BY supplier_org_name
)
```

**NPR Calculation**:
```
NPR % for Year Y = (Payout in Year Y / Base Year Payout) × 100
Where Base Year = Cohort's first year with payouts
```

---

## New Query: Core Action State Counts

**Location**: `queries/supply-am/core-action-state-counts.sql`

**Output** (for dashboard metrics):
| metric | active | loosing | lost | inactive | total |
|--------|--------|---------|------|----------|-------|
| Supplier Count | 142 | 12 | 34 | 8 | 196 |
| Net Payout $ | $3.2M | $400K | $0 | $0 | $3.6M |

**Also create for Demand side**: `queries/demand-sales/core-action-state-counts.sql`

---

## Update bigquery_client.py

### Existing functions to modify:
- `get_supply_nrr()` - Remove exclusion, include unlinked
- `get_supply_nrr_details()` - Same changes

### New functions to add:
```python
def get_supplier_development() -> List[Dict]:
    """Fetch Supplier_Development view data."""

def get_supplier_cohort_matrix() -> List[Dict]:
    """Fetch cohort_retention_matrix_by_supplier data."""

def get_core_action_state_counts(entity: str = 'supplier') -> Dict:
    """Fetch Active/Loosing/Lost counts for dashboard.
    entity: 'supplier' or 'customer'
    """
```

---

## Files to Create/Modify

### SQL Views (BigQuery - deploy to App_KPI_Dashboard)
| File | Action | BigQuery View Name |
|------|--------|-------------------|
| `sql/views/supplier-development.sql` | CREATE | `Supplier_Development` |
| `sql/views/cohort-payout-retention-matrix-supplier.sql` | CREATE | `cohort_payout_retention_matrix_by_supplier` |

### SQL Queries (standalone, not views)
| File | Action | Purpose |
|------|--------|---------|
| `queries/supply-am/supply-npr-summary-by-year.sql` | CREATE | P&L-matched yearly payout summary |
| `queries/supply-am/supply-npr-by-supplier.sql` | CREATE | Supplier detail with Unlinked row + TOTAL |
| `queries/supply-am/core-action-state-counts.sql` | CREATE | Active/Loosing/Lost counts for Supply |
| `queries/demand-sales/core-action-state-counts.sql` | CREATE | Active/Loosing/Lost counts for Demand |
| `queries/supply-am/nrr-top-supply-users-financial.sql` | MODIFY | Remove exclusion, rename to NPR terminology |

### Dashboard Code
| File | Action | Purpose |
|------|--------|---------|
| `dashboard/data/bigquery_client.py` | MODIFY | Add new functions, rename NRR→NPR for supply |

### Documentation
| File | Action | Purpose |
|------|--------|---------|
| `queries/supply-am/README.md` | UPDATE | Document NPR, P&L matching, 3 metrics, unlinked approach |
| `docs/metrics/METRIC-IMPLEMENTATION-TRACKER.md` | UPDATE | Add Supply NPR, Supplier Development references |
| `plans/MASTER-IMPLEMENTATION-PLAN.md` | UPDATE | Update Supply AM section with NPR queries |

### Implementation Plan Storage
| File | Action | Purpose |
|------|--------|---------|
| `plans/2026-02-05-supply-npr-implementation.md` | CREATE | Copy this plan to project folder |

**Note:** This plan should be saved to the project's `plans/` directory with date prefix for tracking.

---

## Verification

### 1. P&L Match Test
```sql
-- Query totals should equal QBO P&L for accounts 4200-4230
SELECT SUM(net_payouts) FROM supply_npr_summary_by_year WHERE year = 2025;
-- Expected: $4,045,628 (matches P&L exactly)
```

### 2. Supplier Total Test
```sql
-- TOTAL row should match summary
SELECT * FROM supply_npr_by_supplier WHERE supplier_org_name = 'TOTAL (P&L Match)';
-- 2025 net_payouts should = $4,045,628
```

### 3. Cohort Matrix Total Test
```sql
-- Grand Total row should match P&L
SELECT * FROM cohort_payout_retention_matrix_by_supplier WHERE chart = 'TOTAL';
-- y2025 should = $4,045,628
```

### 4. Core Action State Consistency
```sql
-- Sum of states should equal total suppliers in Supplier_Development
SELECT core_action_state, COUNT(*)
FROM Supplier_Development
GROUP BY 1;
-- Should match core-action-state-counts.sql output
```

### 5. Net Revenue Formula Verification
```sql
-- Net Revenue for a supplier should match:
-- GMV + Discounts - Credit Memos - Payouts + Vendor Credits
SELECT
  supplier_org_name,
  gmv_2025 + discount_2025 - credit_memo_2025 - payout_2025 + vendor_credit_2025 as calculated_net_rev,
  net_revenue_2025,
  -- Should be equal (or very close due to rounding)
  ABS(calculated_net_rev - net_revenue_2025) as variance
FROM Supplier_Development
WHERE variance > 1;  -- Should return 0 rows
```

### 6. Dashboard Verification
- Run dashboard locally
- Verify Supply NPR waterfall chart shows correct $ amounts
- Verify Active/Loosing/Lost counts match queries
- Compare cohort retention matrix colors (green/yellow/red thresholds)

---

## Implementation Order

1. **Phase 1**: Copy this plan to `plans/2026-02-05-supply-npr-implementation.md`
2. **Phase 2**: Update existing NRR queries (remove exclusion, rename to NPR, add TOTAL row)
3. **Phase 3**: Create `Supplier_Development` view with Net Revenue, GMV, Payout columns
4. **Phase 4**: Create `cohort_payout_retention_matrix_by_supplier` view
5. **Phase 5**: Create core-action-state-counts queries (both Supply & Demand)
6. **Phase 6**: Update bigquery_client.py with new functions (rename NRR→NPR for supply)
7. **Phase 7**: Update documentation:
   - `queries/supply-am/README.md`
   - `docs/metrics/METRIC-IMPLEMENTATION-TRACKER.md`
   - `plans/MASTER-IMPLEMENTATION-PLAN.md`
8. **Phase 8**: Commit and push to GitHub

---

## Summary

**Before**:
- Excluded unlinked → NRR ≠ P&L
- No supplier development view
- No cohort retention matrix for suppliers
- No Active/Loosing/Lost metrics
- Mixed terminology (NRR used for both demand and supply)

**After**:
- Include unlinked as "Unlinked (Not in Platform)" row → Totals match P&L exactly
- `Supplier_Development` view with 3 key metrics:
  - **Net Revenue** (what Recess keeps)
  - **GMV** (total marketplace value)
  - **Organizer Payout** (what supplier gets paid)
- `cohort_payout_retention_matrix_by_supplier` shows payout waterfall by cohort
- **NPR (Net Payout Retention)** for suppliers vs **NRR (Net Revenue Retention)** for customers
- Core Action State counts: Active / Loosing / Lost / Inactive
- Waterfall chart visualization with green/yellow/red coloring

**Key Terminology:**
| Side | Metric | Meaning |
|------|--------|---------|
| **Demand** | NRR (Net Revenue Retention) | Did customer spend more with us? |
| **Supply** | NPR (Net Payout Retention) | Did supplier get paid more by us? |

The "Unlinked" row will show:
- How much $ we can't attribute to a specific supplier org
- Year-over-year trend of unlinked volume (should decrease as linkage improves)
- Its own NPR (meaningful for tracking unlinked $ trend over time)

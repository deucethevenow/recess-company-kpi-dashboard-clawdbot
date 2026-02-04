# Company Health Metrics - Phase 1

> **Purpose:** Definitive specification for each Company Health metric
> **Last Updated:** 2026-02-03
> **Status:** Living document - update as queries are validated

---

## Status Tracking

Each metric has TWO validation gates:

| Gate | Meaning |
|------|---------|
| **Query Validated** | SQL query confirmed correct by business owner |
| **Showing in UI** | Metric displays correctly in Streamlit dashboard |

**Complete = Both gates confirmed ✅**

---

## Status Summary

| # | Metric | Owner | Query Validated | Showing in UI | Status |
|---|--------|-------|:---------------:|:-------------:|:------:|
| 1 | Revenue YTD | Jack | ✅ | ❓ | 🔄 |
| 2 | Take Rate % | Deuce | ❌ NEEDS REWORK | ❓ | 🔄 |
| 3 | Demand NRR | Andy | ✅ VALIDATED | ❓ | 🔄 |
| 4 | Supply NRR | Ashton | ❌ NEEDS VALIDATION | ❓ | 🔄 |
| 5 | Pipeline Coverage | Andy | ❓ NEEDS VALIDATION | ❓ | 🔄 |
| 6 | Sellable Inventory | TBD | ⬜ NOT STARTED | ❓ | ⬜ |
| 7 | Time to Fulfill | Victoria | ❓ NEEDS VALIDATION | ❓ | 🔄 |

---

## 1. Revenue YTD (North Star)

| Field | Value |
|-------|-------|
| **Owner** | Jack |
| **Metric** | Revenue YTD |
| **Query Validated** | ✅ Confirmed working |
| **Showing in UI** | ❓ Pending confirmation |

### Calculation
Total recognized revenue year-to-date from QuickBooks invoice lines in revenue accounts (4110-4190).

### Why This Metric Matters
North Star for the entire company. All other metrics ladder up to this. Board, investors, and team alignment all center here.

### Stored Query
```sql
-- Source: src_fivetran_qbo.invoice_line + invoice + account
-- Refresh: Daily

SELECT
    COALESCE(SUM(il.amount), 0) as revenue_ytd
FROM `stitchdata-384118.src_fivetran_qbo.invoice_line` il
JOIN `stitchdata-384118.src_fivetran_qbo.invoice` i
    ON il.invoice_id = i.id
JOIN `stitchdata-384118.src_fivetran_qbo.account` a
    ON il.sales_item_account_id = a.id
WHERE EXTRACT(YEAR FROM i.transaction_date) = @fiscal_year
    AND i._fivetran_deleted = FALSE
    AND a.account_sub_type IN ('SalesOfProductIncome', 'ServiceFeeIncome')
    AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4110 AND 4190
```

### Current Value
```
2026 YTD: $18,283.64
```

### Notes
- Query working correctly
- Will show comparison to 2025 later

---

## 2. Take Rate %

| Field | Value |
|-------|-------|
| **Owner** | Deuce |
| **Metric** | Take Rate % |
| **Query Validated** | ❌ NEEDS REWORK |
| **Showing in UI** | ❓ Pending |

### Original Calculation (from spec)
```
Total 4000 Services Revenue - Events / Total 4100 01 - Marketplace Revenue (GMV)
Target: 45%
```

### Current Query Issue
Using `Supplier_Metrics` view which calculates `take_amount / GMV` - may not match the intended formula above.

### What We Need to Clarify
1. What is "4000 Services Revenue - Events"? (Account number? View?)
2. What is "4100 01 - Marketplace Revenue (GMV)"? (Account number? View?)
3. Should this come from QuickBooks accounts or the Supplier_Metrics view?

### Current Query (NEEDS REWORK)
```sql
-- CURRENT (may be wrong source):
SELECT SAFE_DIVIDE(SUM(take_amount), SUM(GMV)) as take_rate
FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
WHERE Offer_Accepted_Year = 2025

-- Returns: 62.4%
```

### Proposed Query Options
**Option A: QuickBooks Account-Based**
```sql
-- If using QBO accounts directly
-- Need to identify correct account numbers
```

**Option B: Create New View**
```sql
-- If calculation requires custom logic
-- Define exact formula
```

---

## 3. Demand Net Revenue Retention (NRR)

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Metric** | Demand NRR by Cohort Year |
| **Query Validated** | ✅ VALIDATED 2026-02-03 |
| **Showing in UI** | ❓ Pending |

### Calculation
```
Prior year cohort's current year revenue / Their prior year revenue
Target: 107%
```

### Data Source
Uses `App_KPI_Dashboard.cohort_retention_matrix_by_customer` view which tracks revenue by cohort year.

### Validated Query
```sql
-- Get cohort-based NRR
SELECT
    first_year as cohort_year,
    SUM(CAST(y2024 AS FLOAT64)) as rev_2024,
    SUM(CAST(y2025 AS FLOAT64)) as rev_2025,
    SUM(CAST(y2026 AS FLOAT64)) as rev_2026
FROM `stitchdata-384118.App_KPI_Dashboard.cohort_retention_matrix_by_customer`
WHERE first_year IN (2024, 2025)
GROUP BY first_year
```

### Current Values
| Comparison | Cohort | Original Revenue | Next Year Revenue | NRR |
|------------|--------|------------------|-------------------|-----|
| **2025 Actuals** | 2024 | $1,517,381 | $337,591 | **22.2%** |
| **2026 YTD** | 2025 | $1,008,415 | $1,549 | **0.15%*** |

*Early year (Feb 3) - 2026 YTD expected to be low.

### Notes
- NRR below 100% indicates cohort contraction (customers spending less YoY)
- Target is 107% (growth)
- Dashboard should show both 2026 YTD and 2025 Actuals for context

---

## 4. Supply Net Revenue Retention (NRR)

| Field | Value |
|-------|-------|
| **Owner** | Ashton |
| **Metric** | Supply NRR by Cohort Year |
| **Query Validated** | ❌ NEEDS VALIDATION |
| **Showing in UI** | ❓ Pending |

### Original Calculation (from spec)
```
2026 Net revenue from 2025 Cohort / 2025 Cohort Net revenue
Target: 107%
```

### Current Query
```sql
WITH supplier_yearly AS (
    SELECT
        Supplier_Name,
        SUM(CASE WHEN Offer_Accepted_Year = 2024 THEN Payouts ELSE 0 END) as payouts_2024,
        SUM(CASE WHEN Offer_Accepted_Year = 2025 THEN Payouts ELSE 0 END) as payouts_2025
    FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
    GROUP BY Supplier_Name
)
SELECT
    SAFE_DIVIDE(
        SUM(CASE WHEN payouts_2024 > 0 THEN payouts_2025 END),
        SUM(CASE WHEN payouts_2024 > 0 THEN payouts_2024 END)
    ) as supply_nrr
FROM supplier_yearly

-- Returns: 66.7%
```

### What We Need to Clarify
1. Is the calculation correct (payouts to same suppliers YoY)?
2. Should it be 2026 vs 2025 instead of 2025 vs 2024?
3. Is there an existing Supply NRR view we should use?

---

## 5. Pipeline Coverage

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Metric** | Pipeline Coverage |
| **Query Validated** | ❓ NEEDS VALIDATION |
| **Showing in UI** | ❓ Pending |

### Calculation
Weighted Pipeline / Remaining Quota

### Current Query
```sql
SELECT
    SAFE_DIVIDE(
        SUM(COALESCE(SAFE_CAST(d.property_amount AS FLOAT64), 0) *
            COALESCE(p.probability, 0.1)),
        2070000  -- HARDCODED - needs to be dynamic
    ) as pipeline_coverage
FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage` p
    ON d.deal_pipeline_stage_id = p.stage_id
WHERE d.is_deleted = false
    AND COALESCE(p.is_closed, false) = false

-- Returns: 5.4x
```

### Issues
- Quota ($2,070,000) is hardcoded
- Need dynamic quota source

---

## 6. Total Unique Sellable Inventory

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Metric** | Total Sellable Inventory |
| **Query Validated** | ⬜ NOT STARTED |
| **Showing in UI** | ❓ Pending |

### Notes
- PRD needed to define "sellable" criteria
- Raw listing count: 27,094

---

## 7. Avg / Median Time to Fulfill Contract

| Field | Value |
|-------|-------|
| **Owner** | Victoria |
| **Metric** | Time to Fulfill Contract |
| **Query Validated** | ❓ NEEDS VALIDATION |
| **Showing in UI** | ❓ Pending |

### Current Query
```sql
SELECT
    AVG(days_between_first_last) as avg_days,
    APPROX_QUANTILES(days_between_first_last, 100)[OFFSET(50)] as median_days
FROM `stitchdata-384118.App_KPI_Dashboard.Days_to_Fulfill_Contract_Program`
WHERE days_between_first_last IS NOT NULL

-- Returns: Avg 139 days, Median 14 days
```

### Issues
- Which metric to show: avg or median?
- Recommend median due to outliers


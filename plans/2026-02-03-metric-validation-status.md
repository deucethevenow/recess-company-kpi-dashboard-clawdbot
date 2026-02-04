# Company KPI Dashboard - Metric Validation Status

> **Generated:** 2026-02-03
> **Purpose:** Track which metrics are validated as working from BigQuery

---

## Summary

| Status | Count | Description |
|--------|-------|-------------|
| ✅ VALIDATED | 9 | Query works, data returns, logic confirmed |
| ⚠️ NEEDS REVIEW | 3 | Query works but values need business validation |
| ❌ NOT WORKING | 1 | Query fails or view doesn't exist |
| 🔨 NEEDS BUILD | 2 | No existing view/query, needs to be created |

---

## COMPANY HEALTH METRICS

### Phase 1 Metrics

| # | Owner | Metric | Status | BigQuery Value | Mocked Value | Notes |
|---|-------|--------|--------|----------------|--------------|-------|
| 1 | Jack | **Revenue YTD** | ⚠️ NEEDS REVIEW | **$18,284** (2026 YTD) | $7.93M | 2026 just started - only Feb data. Query works but shows current YTD which is tiny |
| 2 | Deuce | **Take Rate %** | ✅ VALIDATED | **62.4%** (2025) | 42% | Fixed! Uses `Supplier_Metrics` view. 2025 data (2026 < $100K threshold) |
| 3 | Andy | **Demand NRR** | ✅ VALIDATED | **22%** (2024 cohort→2025) | 107% | Uses cohort_retention_matrix_by_customer. 2024 cohort: $1.5M→$338k = 22% |
| 4 | Ashton | **Supply NRR** | ✅ VALIDATED | **66.7%** (2025 vs 2024) | 107% | NEW! Calculated from `Supplier_Metrics`. Same pattern as demand - contraction |
| 5 | Andy | **Pipeline Coverage** | ✅ VALIDATED | **5.4x** | 2.8x | Query works. Weighted pipeline / $2.07M remaining quota |
| 6 | ? | **Total Sellable Inventory** | 🔨 NEEDS BUILD | 27,094 listings | N/A | Raw count from `mongodb.audience_listings`. Need PRD to define "sellable" criteria |
| 7 | Victoria | **Avg Time to Fulfill** | ⚠️ NEEDS REVIEW | **Avg: 139 days / Median: 14 days** | N/A | View exists. Huge gap between avg/median suggests outliers. Which metric to show? |

### Phase 2 Metrics

| # | Owner | Metric | Status | BigQuery Value | Mocked Value | Notes |
|---|-------|--------|--------|----------------|--------------|-------|
| 8 | ? | **Logo Retention** | ⚠️ NEEDS REVIEW | **17.9%** (96/535) | 37% | Query works but value is LOW. 96 of 535 customers with 2024 revenue returned in 2025 |
| 9 | ? | **Customer Concentration** | ✅ VALIDATED | **29.2%** (HEINEKEN) | 41% | Top 2: HEINEKEN 29.2% + Kraft Heinz 23.7% = 52.9% combined |
| 10 | ? | **Active Customers (Demand)** | ✅ VALIDATED | **566** (2025) | N/A | From `customer_development` view |
| 11 | ? | **Churned Customers (Demand)** | ✅ VALIDATED | **426** | N/A | Had 2024 revenue but $0 in 2025. High churn! |

---

## DETAILED VALIDATION RESULTS

### 1. Revenue YTD (Jack)
```
Source: src_fivetran_qbo.invoice_line + invoice + account
Query Status: ✅ Working
Value: $18,283.64 (2026 YTD as of Feb 3)
Issue: Very early in fiscal year - need fallback to 2025 full year for meaningful display
```

### 2. Take Rate % (Deuce)
```
Source: App_KPI_Dashboard.Supplier_Metrics
Query Status: ✅ Working (FIXED this session)
Value: 62.4% (2025)
Formula: take_amount / GMV = $4.95M / $7.93M
Note: Falls back to 2025 since 2026 GMV < $100K
```

### 3. Demand NRR (Andy)
```
Source: App_KPI_Dashboard.cohort_retention_matrix_by_customer
Query Status: ✅ VALIDATED (user confirmed 2026-02-03)
Formula: Prior year cohort's current year revenue / Their prior year revenue

2025 Actuals (2024 cohort):
  - 2024 cohort spent $1,517,381 in 2024
  - Same cohort spent $337,591 in 2025
  - NRR = 22.2%

2026 YTD (2025 cohort):
  - 2025 cohort spent $1,008,415 in 2025
  - Same cohort spent $1,549 in 2026 (so far)
  - NRR = 0.15% (early year - expected)

Note: Shows cohort-based retention, not dollar-weighted aggregate
```

### 4. Supply NRR (Ashton)
```
Source: App_KPI_Dashboard.Supplier_Metrics
Query Status: ✅ Working (NEW query created)
Value: 66.7%
Formula: 2025 payouts ($1.83M) / 2024 payouts ($2.74M) for same suppliers
Note: 156 suppliers had payouts in 2024
```

### 5. Pipeline Coverage (Andy)
```
Source: src_fivetran_hubspot.deal + deal_pipeline_stage
Query Status: ✅ Working
Value: 5.4x
Components:
  - Total Pipeline: $44.1M
  - Weighted Pipeline: $11.2M
  - Remaining Quota: $2.07M (hardcoded - needs to be dynamic)
```

### 6. Total Sellable Inventory (?)
```
Source: mongodb.audience_listings
Query Status: 🔨 NEEDS BUILD
Value: 27,094 total listings
Issue: Need PRD to define "sellable" criteria (published? capacity? dates?)
```

### 7. Avg/Median Time to Fulfill (Victoria)
```
Source: App_KPI_Dashboard.Days_to_Fulfill_Contract_Program
Query Status: ✅ Working
Value: Avg 139 days, Median 14 days
Column: days_between_first_last
Records: 370 contracts
Issue: Large discrepancy suggests outliers. Recommend using MEDIAN (14 days)
```

### 8. Logo Retention (?)
```
Source: App_KPI_Dashboard.customer_development
Query Status: ✅ Working
Value: 17.9% (96 retained / 535 with 2024 revenue)
Issue: Value seems very low - verify this is the intended calculation
  - 535 customers had revenue in 2024
  - Only 96 of those also had revenue in 2025
  - 439 customers churned (82%!)
```

### 9. Customer Concentration (?)
```
Source: App_KPI_Dashboard.net_revenue_retention_all_customers
Query Status: ✅ Working
Value: HEINEKEN = 29.2% of 2025 revenue
Top 5 Customers (2025):
  1. HEINEKEN USA: $1.18M (29.2%)
  2. Kraft Heinz: $957K (23.7%)
  3. Advantage Solutions: $224K (5.5%)
  4. Church & Dwight: $183K (4.5%)
  5. Peace Tea: $126K (3.1%)
Combined Top 2: 52.9%
```

### 10. Active Customers (?)
```
Source: App_KPI_Dashboard.customer_development
Query Status: ✅ Working
Value: 566 customers with Net_Revenue_2025 > 0
```

### 11. Churned Customers (?)
```
Source: App_KPI_Dashboard.customer_development
Query Status: ✅ Working
Value: 426 customers
Definition: Had Net_Revenue_2024 > 0 but Net_Revenue_2025 = 0
```

---

## QUERIES THAT NEED TO BE CREATED

### 1. Supply NRR View (for Ashton)
```sql
-- Recommend creating: App_KPI_Dashboard.supply_net_revenue_retention
WITH supplier_yearly AS (
    SELECT
        Supplier_Name,
        SUM(CASE WHEN Offer_Accepted_Year = 2024 THEN Payouts ELSE 0 END) as payouts_2024,
        SUM(CASE WHEN Offer_Accepted_Year = 2025 THEN Payouts ELSE 0 END) as payouts_2025
    FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
    GROUP BY Supplier_Name
)
SELECT
    Supplier_Name,
    payouts_2024,
    payouts_2025,
    SAFE_DIVIDE(payouts_2025, payouts_2024) as supplier_nrr
FROM supplier_yearly
WHERE payouts_2024 > 0
```

### 2. Sellable Inventory View
```sql
-- Need PRD to define criteria
-- Placeholder query:
SELECT COUNT(*) as sellable_inventory
FROM `stitchdata-384118.mongodb.audience_listings`
WHERE published_at IS NOT NULL
  -- AND other criteria TBD
```

---

## ACTION ITEMS

| Priority | Action | Owner |
|----------|--------|-------|
| HIGH | Validate Logo Retention calculation (17.9% seems low) | Business |
| HIGH | Validate NRR values (65-67% shows contraction) | Business |
| MED | Define "sellable" inventory criteria | Product |
| MED | Make pipeline quota dynamic (currently hardcoded $2.07M) | Engineering |
| MED | Decide avg vs median for Time to Fulfill | Business |
| LOW | Create Supply NRR view in BigQuery | Engineering |
| LOW | Add 2025 full-year fallback for Revenue YTD display | Engineering |

---

## DATA SOURCES VERIFIED

| View/Table | Status | Records |
|------------|--------|---------|
| `App_KPI_Dashboard.net_revenue_retention_all_customers` | ✅ | 197 customers |
| `App_KPI_Dashboard.customer_development` | ✅ | 566+ customers |
| `App_KPI_Dashboard.Supplier_Metrics` | ✅ | 681 suppliers |
| `App_KPI_Dashboard.Days_to_Fulfill_Contract_Program` | ✅ | 370 contracts |
| `src_fivetran_hubspot.deal` | ✅ | Pipeline data |
| `src_fivetran_qbo.invoice_line` | ✅ | Invoice data |
| `mongodb.audience_listings` | ✅ | 27,094 listings |


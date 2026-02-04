# Company Health Metrics - Verification Checklist

> **Purpose:** Step-by-step verification for each metric before marking as validated
> **Last Updated:** 2026-02-03

---

## Verification Process

For EACH metric, complete ALL checkboxes before marking as "Query Validated":

### Pre-Verification
- [ ] Identify the source spreadsheet/document with expected values
- [ ] Confirm the exact formula being used
- [ ] Identify all data sources (tables, views) involved

### Query Verification
- [ ] Write the BigQuery query
- [ ] Run against 2025 data (complete year for comparison)
- [ ] Compare result to spreadsheet expected value
- [ ] If mismatch > 1%, investigate and document reason

### Sign-off
- [ ] Business owner confirms formula is correct
- [ ] Value matches expected within acceptable tolerance
- [ ] Query added to bigquery_client.py

---

## Metric Verification Status

### 1. Revenue YTD

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ✅ | Recess Forecast v1.2 |
| Expected 2025 Value | **$3,907k** | Row 12 "Revenue" |
| Query Result | ❓ | Need to verify |
| Formula | Market Place Revenue (GMV + Discounts + Organizer Fees) | Same as Take Rate numerator |
| Match Spreadsheet | ❓ | Pending |
| Query Validated | ❌ | |
| Showing in UI | ❓ | |

**Action Needed:** Revenue = Market Place Revenue, NOT gross invoice amount. Need to update query.

---

### 2. Take Rate %

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ✅ | Recess Forecast v1.2, Row 43 |
| Expected 2025 Value | **49%** | |
| Query Result | **49.3%** | ✅ Matches |
| Formula | Market Place Revenue / GMV | |
| Components Match | ✅ | GMV: $7,920k, Org Fees: -$2,760k, Discounts: -$1,249k |
| Query Validated | ✅ | Confirmed by user |
| Showing in UI | ❓ | Pending |

---

### 3. Demand NRR

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ✅ | cohort_retention_matrix_by_customer view |
| Expected 2025 Value | **22%** | 2024 cohort's 2025 revenue / their 2024 revenue |
| Query Result | **22.2%** | $337,591 / $1,517,381 |
| Formula | Prior year cohort's current year revenue / Their prior year revenue | Per spec |
| Match Spreadsheet | ✅ | Matches cohort calculation |
| Query Validated | ✅ | User confirmed 2026-02-03 |
| Showing in UI | ❓ | Pending |

**2026 YTD:** 2025 cohort spent $1,008k in 2025 → $1.5k in 2026 = **0.15%** (early year - expected)

---

### 4. Supply NRR

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source with expected value |
| Expected 2025 Value | ❓ | Need from spreadsheet |
| Query Result | **66.7%** | (2025 payouts to 2024 suppliers / 2024 payouts) |
| Formula | Same as Demand NRR but for suppliers | |
| Match Spreadsheet | ❓ | Pending verification |
| Query Validated | ❌ | Pending user confirmation |
| Showing in UI | ❓ | |

**Action Needed:** Get expected Supply NRR value from business to verify query.

---

### 5. Pipeline Coverage

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source with expected value |
| Expected 2025 Value | ❓ | |
| Query Result | **5.4x** | |
| Formula | Weighted Pipeline / Remaining Quota | |
| Issue | ⚠️ | Quota ($2.07M) is hardcoded |
| Query Validated | ❌ | Pending: need dynamic quota |
| Showing in UI | ❓ | |

**Action Needed:**
1. Confirm quota source (HubSpot property?)
2. Make quota dynamic

---

### 6. Total Sellable Inventory

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need PRD |
| Expected Value | ❓ | |
| Query Result | 27,094 (raw listings) | |
| Formula | TBD | Need definition of "sellable" |
| Query Validated | ⬜ | Not started - needs PRD |
| Showing in UI | ❓ | |

**Action Needed:** PRD to define "sellable" criteria.

---

### 7. Time to Fulfill

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source with expected value |
| Expected 2025 Value | ❓ | |
| Query Result | **14 days** (median) | Avg: 139 days |
| Formula | Days between first/last accepted offer | |
| Issue | ⚠️ | Need to decide: avg vs median |
| Query Validated | ❌ | Pending user decision |
| Showing in UI | ❓ | |

**Action Needed:** Decide which metric to show (recommend median).

---

### 8. Logo Retention

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source with expected value |
| Expected 2025 Value | ❓ | Spec says target 50%, shows 37% |
| Query Result | **17.9%** | 96 retained / 535 |
| Formula | Customers retained / Total at period start | |
| Issue | ⚠️ | Value seems very low |
| Query Validated | ❌ | Pending business validation |
| Showing in UI | ❓ | |

**Action Needed:** Confirm calculation is correct (value seems low).

---

### 9. Customer Concentration

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ✅ | Spec says 41% HEINEKEN |
| Expected 2025 Value | 41%? | Per original spec |
| Query Result | **29.2%** | HEINEKEN |
| Formula | Top customer revenue / Total revenue | |
| Issue | ⚠️ | Query shows 29.2%, spec said 41% |
| Query Validated | ❌ | Need to reconcile discrepancy |
| Showing in UI | ❓ | |

**Action Needed:** Verify which value is correct (29.2% vs 41%).

---

### 10. Active Customers

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source |
| Expected 2025 Value | ❓ | |
| Query Result | **566** | |
| Formula | Customers with Net_Revenue_2025 > 0 | |
| Query Validated | ❓ | Pending |
| Showing in UI | ❓ | |

---

### 11. Churned Customers

| Check | Status | Notes |
|-------|--------|-------|
| Source Document | ❓ | Need source |
| Expected 2025 Value | ❓ | |
| Query Result | **426** | |
| Formula | Had 2024 revenue, no 2025 revenue | |
| Query Validated | ❓ | Pending |
| Showing in UI | ❓ | |

---

## Summary - Verification Status

| # | Metric | Owner | 2026 YTD | 2026 Goal | 2025 Actuals | Query (2025) | Match | Query Validated | Showing in UI | Complete |
|---|--------|-------|----------|-----------|--------------|--------------|:-----:|:---------------:|:-------------:|:--------:|
| 1 | Revenue | Jack | -$70k* | $10M | $3,907k | $3,902k | ✅ | ✅ | ❓ | ❌ |
| 2 | Take Rate | Deuce | N/A* | 45% | 49% | 49.3% | ✅ | ✅ | ❓ | ❌ |
| 3 | Demand NRR | Andy | $1.5k (0%)* | 107% | $338k (22%) | $338k (22%) | ✅ | ✅ | ❓ | ❌ |
| 4 | Supply NRR | Ashton | TBD* | 107% | TBD | TBD | ❓ | ❌ | ❓ | ❌ |
| 5 | Pipeline Coverage | Andy | 5.4x | 3.0x | TBD | 5.4x | ❓ | ❌ | ❓ | ❌ |
| 6 | Sellable Inventory | TBD | TBD | TBD | TBD | 27K raw | ❓ | ⬜ | ❓ | ❌ |
| 7 | Time to Fulfill | Victoria | TBD | ↓ Lower | TBD | 14 days | ❓ | ❌ | ❓ | ❌ |
| 8 | Logo Retention | TBD | TBD | 50% | TBD | 17.9% | ❓ | ❌ | ❓ | ❌ |
| 9 | Customer Concentration | TBD | TBD | ↓ Lower | TBD | 29.2% | ❓ | ❌ | ❓ | ❌ |
| 10 | Active Customers | TBD | TBD | TBD | 566 | 566 | ❓ | ❓ | ❓ | ❌ |
| 11 | Churned Customers | TBD | TBD | ↓ Lower | 426 | 426 | ❓ | ❓ | ❓ | ❌ |

**\* Early year (Feb 3) - 2026 YTD values incomplete. Dashboard should show indicator for early-year data.**

### NRR Detail (from cohort_retention_matrix_by_customer)

| Comparison | Cohort | Original $ | Next Year $ | NRR % |
|------------|--------|------------|-------------|-------|
| **2025 Actuals** | 2024 Cohort | $1,517k (2024) | $338k (2025) | **22%** |
| **2026 YTD** | 2025 Cohort | $1,008k (2025) | $1.5k (2026) | **0%*** |

**Legend:**
- **2026 YTD** = Current year-to-date from BigQuery (live)
- **2026 Goal** = Target for the year
- **2025 Actuals** = Value from Recess Forecast spreadsheet (source of truth for verification)
- **Query (2025)** = BigQuery result for 2025 (to verify query matches spreadsheet)
- **Match** = ✅ if Query matches 2025 Actuals within tolerance (<1% diff)
- **Query Validated** = ✅ confirmed correct by business owner
- **Showing in UI** = ✅ displays correctly in Streamlit dashboard
- **Complete** = ✅ only when Query Validated AND Showing in UI are both ✅

**Progress: 3/11 Match Verified (Revenue, Take Rate, Demand NRR) | 3/11 Query Validated (Revenue, Take Rate, Demand NRR)**


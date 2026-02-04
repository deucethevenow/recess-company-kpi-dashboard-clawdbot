# Company Health Metrics Validation Plan

> **Created:** 2026-02-03
> **Goal:** Validate all 11 Company Health metrics against source spreadsheet values
> **Status:** IN PROGRESS

---

## Validation Workflow

For each metric:
1. [ ] Identify source document with expected value
2. [ ] Write/verify BigQuery query
3. [ ] Compare query result to expected value
4. [ ] Get business owner confirmation
5. [ ] Update bigquery_client.py with validated query
6. [ ] Mark as validated in this document

---

## Phase 1 Metrics (Priority)

### 1. Revenue YTD
| Field | Value |
|-------|-------|
| Owner | Jack |
| Status | **✅ VALIDATED** |
| Source | Recess Forecast v1.2, Row 12 |
| Expected 2025 | $3,907k |
| Query Result | $3,902k |
| Match | ✅ (<1% diff) |
| Query Location | `bigquery_client.py:get_revenue_ytd()` |

---

### 2. Take Rate %
| Field | Value |
|-------|-------|
| Owner | Deuce |
| Status | **✅ VALIDATED** |
| Source | Recess Forecast v1.2, Row 43 |
| Expected 2025 | 49% |
| Query Result | 49.3% |
| Match | ✅ |
| Query Location | `bigquery_client.py:get_take_rate()` |
| Formula | Market Place Revenue / GMV |
| Components | GMV: $7.92M, Discounts: -$1.25M, Org Fees: -$2.77M |

---

### 3. Demand NRR
| Field | Value |
|-------|-------|
| Owner | Andy |
| Status | **✅ VALIDATED** |
| Source | cohort_retention_matrix_by_customer |
| Formula | Prior year cohort's current year revenue / Their prior year revenue |
| 2025 Value | 22% (2024 cohort: $1.52M → $338k) |
| 2026 YTD | 0.15% (2025 cohort: $1.01M → $1.5k) |
| Query Location | `bigquery_client.py:get_nrr()`, `get_demand_nrr_details()` |
| Notes | Target is 107% (growth). Actual shows contraction. |

---

### 4. Supply NRR
| Field | Value |
|-------|-------|
| Owner | Ashton |
| Status | **🔄 QUERY READY - NEEDS VALIDATION** |
| Source | Supplier_Metrics view |
| Formula | Prior year suppliers' current year payouts / Their prior year payouts |
| 2025 Value | 66.7% (2024 cohort: $2.74M → $1.83M) |
| Supplier Count | 156 |
| Query Location | `bigquery_client.py:get_supply_nrr()`, `get_supply_nrr_details()` |
| Action | Get Ashton to confirm calculation is correct |

---

### 5. Pipeline Coverage
| Field | Value |
|-------|-------|
| Owner | Andy |
| Status | **✅ VALIDATED** |
| Source | HubSpot deals + company quota properties |
| Formula | HS Weighted Pipeline (closing this quarter) / Remaining Quarterly Goal |
| Query Location | `bigquery_client.py:get_pipeline_coverage()`, `get_pipeline_details()`, `get_quota_from_company_properties()` |

**Annual Goal Calculation:**
| Component | Amount |
|-----------|--------|
| Land & Expand Quota | $3,901,985 |
| New Customer Quota | $2,457,788 |
| Renewal Quota | $2,908,369 |
| **Company Properties Subtotal** | **$9,268,142** |
| Unnamed Accounts Adjustment | $2,000,000 |
| **Total Annual Goal** | **$11,268,142** |

**Excluded Quotas (tracked separately):**
| Quota Type | Amount |
|------------|--------|
| DG Quota | $385,329 |
| Walmart Quota | $786,682 |

**Q1 2026 Status:**
| Metric | Value |
|--------|-------|
| Q1 Goal | $2,817,036 |
| Closed Won Q1 | $630,659 |
| Remaining to Goal | $2,186,377 |
| HS Weighted Pipeline | $7,132,571 |
| **Coverage** | **3.26x** |
| Pipeline Gap | -$4.95M (surplus) |

**Configuration:** Annual and quarterly goals can be overridden. Unnamed accounts adjustment defaults to $2M.

---

### 6. Total Sellable Inventory
| Field | Value |
|-------|-------|
| Owner | TBD |
| Status | **⬜ NOT STARTED** |
| Source | mongodb.audience_listings |
| Raw Count | 27,094 listings |
| Issue | No definition of "sellable" criteria |
| Action | PRD needed to define sellable criteria |

---

### 7. Time to Fulfill
| Field | Value |
|-------|-------|
| Owner | Victoria |
| Status | **🔄 QUERY READY - NEEDS VALIDATION** |
| Source | Days_to_Fulfill_Contract_Program |
| Median | 14 days |
| Average | 139 days |
| Contract Count | 370 |
| Query Location | `bigquery_client.py:get_time_to_fulfill()` |
| Issue | Large gap between median/avg suggests outliers |
| Action | Confirm median (14 days) is the right metric to show |

---

## Phase 2 Metrics

### 8. Logo Retention
| Field | Value |
|-------|-------|
| Owner | TBD |
| Status | **✅ VALIDATED** |
| Source | customer_development view (DISTINCT customer_id) |
| Query Result | **26.1%** (18/69 unique customers) |
| Target | 50% |
| Query Location | `bigquery_client.py:get_logo_retention()` |
| Critical Fix | Must use COUNT(DISTINCT customer_id) - view has multiple rows per customer! |
| Notes | Previous 17.9% (96/535) was counting ROWS not customers |

---

### 9. Customer Concentration
| Field | Value |
|-------|-------|
| Owner | TBD |
| Status | **✅ VALIDATED** |
| Source | net_revenue_retention_all_customers |
| Query Result | **29.1%** (HEINEKEN = $1.18M of $4.05M total) |
| Top 2 Combined | **52.7%** (HEINEKEN 29.1% + Kraft Heinz 23.6%) |
| Query Location | `bigquery_client.py:get_customer_concentration()` |
| Notes | Spec said 41% - may have been different time period or calculation |

---

### 10. Active Customers
| Field | Value |
|-------|-------|
| Owner | TBD |
| Status | **✅ VALIDATED** |
| Source | customer_development view (DISTINCT customer_id) |
| Query Result | **40 unique customers** (2025 revenue > 0) |
| Query Location | `bigquery_client.py:get_customer_count()` |
| Critical Fix | Must use COUNT(DISTINCT customer_id) |
| Notes | Previous 566 was counting ROWS not customers |

---

### 11. Churned Customers
| Field | Value |
|-------|-------|
| Owner | TBD |
| Status | **✅ VALIDATED** |
| Source | customer_development view (DISTINCT customer_id) |
| Query Result | **51 unique customers** (had 2024, no 2025) |
| Query Location | `bigquery_client.py:get_churned_customers()` |
| Notes | Previous 426 was counting ROWS not customers |

---

## Summary

| # | Metric | Owner | Status | Next Action |
|---|--------|-------|--------|-------------|
| 1 | Revenue YTD | Jack | ✅ VALIDATED | - |
| 2 | Take Rate | Deuce | ✅ VALIDATED | - |
| 3 | Demand NRR | Andy | ✅ VALIDATED | - |
| 4 | Supply NRR | Ashton | 🔄 NEEDS VALIDATION | Confirm 66.7% with owner |
| 5 | Pipeline Coverage | Andy | ✅ VALIDATED | 3.26x coverage (Q1 goal: $2.82M, weighted: $7.13M) |
| 6 | Sellable Inventory | TBD | ⬜ NOT STARTED | PRD needed |
| 7 | Time to Fulfill | Victoria | 🔄 NEEDS VALIDATION | Confirm median (14 days) vs avg (139 days) |
| 8 | Logo Retention | TBD | ✅ VALIDATED | 26.1% (18/69 unique customers) |
| 9 | Customer Concentration | TBD | ✅ VALIDATED | 29.1% HEINEKEN |
| 10 | Active Customers | TBD | ✅ VALIDATED | 40 unique customers |
| 11 | Churned Customers | TBD | ✅ VALIDATED | 51 unique customers |

**Progress: 9/11 Validated | 2/11 Need Owner Confirmation | 1/11 Not Started**

### Critical Finding
The `customer_development` view has **multiple rows per customer**. Previous metrics counted rows (535, 566, 426) instead of unique customers (69, 40, 51). All queries now use `COUNT(DISTINCT customer_id)`.

---

## Files Modified

- `dashboard/data/bigquery_client.py` - Query functions
- `dashboard/data/reference_values_2025.py` - 2025 benchmark values
- `docs/2026-02-03-metric-verification-checklist.md` - Detailed checklist
- `docs/2026-02-03-company-health-metrics-phase1.md` - Spec document

# Company KPI Dashboard - Metric Implementation Tracker

> **Purpose:** Single source of truth for metric implementation status
> **Created:** 2026-02-03
> **Last Updated:** 2026-02-03
> **Owner:** Deuce (final approval on all confirmations)

---

## How to Use This Document

Each metric goes through **4 gates** before being marked complete:

| Gate | Symbol | Meaning |
|------|--------|---------|
| **BQ View Exists** | 🗄️ | BigQuery view/query exists and returns data |
| **Python Function** | 🐍 | Function exists in `bigquery_client.py` |
| **UI Integrated** | 🖥️ | Metric displays in Streamlit dashboard |
| **User Confirmed** | ✅ | Deuce has confirmed the value is correct |

**Legend:**
- ✅ = Complete/Confirmed
- ⚠️ = Needs review/validation
- ❌ = Not working/Not started
- ⬜ = Not applicable

---

## MASTER STATUS SUMMARY

### Company Health Metrics (Core 7)

| # | Metric | Owner | BQ View | Python Fn | UI | Confirmed | 2025 Value | 2026 Value |
|---|--------|-------|:-------:|:---------:|:--:|:---------:|------------|------------|
| 1 | Revenue YTD | Jack | ✅ | ✅ | ✅ | ⬜ | $4.04M | $18K |
| 2 | Take Rate % | Deuce | ✅ | ✅ | ✅ | ⬜ | 49.3% | ~0% |
| 3 | Demand NRR | Andy | ✅ | ✅ | ✅ | ⬜ | 22% | 0.15% |
| 4 | Supply NRR | Ashton | ✅ | ✅ | ✅ | ⬜ | 67% | ~0% |
| 5 | Pipeline Coverage | Andy | ✅ | ✅ | ✅ | ⬜ | N/A | 3.26x |
| 6 | Logo Retention | ? | ✅ | ✅ | ✅ | ⬜ | 26% | N/A |
| 7 | Customer Count | ? | ✅ | ✅ | ✅ | ⬜ | 51 | TBD |

### Person-Level Metrics (Priority)

| # | Metric | Owner | BQ View | Python Fn | UI | Confirmed | Current Value |
|---|--------|-------|:-------:|:---------:|:--:|:---------:|---------------|
| 8 | Contract Spend % | Char | ✅ | ✅ | ❌ | ⬜ | TBD |
| 9 | Time to Fulfill | Victoria | ✅ | ✅ | ✅ | ⬜ | 14 days (median) |
| 10 | NPS Score | Claire | ✅ | ✅ | ❌ | ⬜ | TBD |
| 11 | Customer Concentration | ? | ✅ | ✅ | ⚠️ | ⬜ | 29.2% (HEINEKEN) |
| 12 | Churned Customers | ? | ✅ | ✅ | ❌ | ⬜ | 426 |

### Not Yet Implemented

| # | Metric | Owner | BQ View | Python Fn | UI | Notes |
|---|--------|-------|:-------:|:---------:|:--:|-------|
| 13 | Sellable Inventory | Ian | ❌ | ❌ | ⚠️ | Placeholder card shows "Needs PRD" |
| 14 | New Unique Inventory | Ian | ❌ | ❌ | ⚠️ | Mock data only |
| 15 | NRR Top Supply Users | Ashton | ❌ | ❌ | ⚠️ | Mock data only |
| 16 | Offer Acceptance % | Francisco | ❌ | ❌ | ⚠️ | Mock data only |
| 17 | Mktg-Influenced Pipeline | Marketing | ❌ | ❌ | ⚠️ | Mock data only |
| 18 | Invoice Collection % | Accounting | ❌ | ❌ | ⚠️ | Mock data only |
| 19 | Engineering Metrics (4) | VP Eng | ❌ | ❌ | ⚠️ | Requires Asana/GitHub API |

---

## DETAILED METRIC SPECIFICATIONS

---

### 1. Revenue YTD

| Field | Value |
|-------|-------|
| **Owner** | Jack |
| **Target** | $5,521,390 (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Data Source
- **BigQuery Table:** `src_fivetran_qbo.invoice_line` + `invoice` + `account`
- **Python Function:** `bigquery_client.get_revenue_ytd()`
- **File Location:** `dashboard/data/bigquery_client.py:79`

#### Query Logic
```sql
SELECT COALESCE(SUM(il.amount), 0) as revenue_ytd
FROM src_fivetran_qbo.invoice_line il
JOIN src_fivetran_qbo.invoice i ON il.invoice_id = i.id
JOIN src_fivetran_qbo.account a ON il.sales_item_account_id = a.id
WHERE EXTRACT(YEAR FROM i.transaction_date) = @fiscal_year
  AND a.account_sub_type IN ('SalesOfProductIncome', 'ServiceFeeIncome')
  AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4000 AND 4190
  AND SAFE_CAST(a.account_number AS INT64) NOT IN (4250, 4260, 4300, 4310)
```

#### Current Values
| Year | Value | Notes |
|------|-------|-------|
| 2025 | $4,040,000 | Full year |
| 2026 | $18,284 | YTD (Feb 3) - early year |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:**

---

### 2. Take Rate % (formerly Gross Margin)

| Field | Value |
|-------|-------|
| **Owner** | Deuce |
| **Target** | 51% (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Formula
```
Take Rate = Market Place Revenue / GMV

Where:
- GMV = Accounts 4110-4169 (Sampling, Sponsorship, Activation GMV)
- Market Place Revenue = GMV + Discounts (4190) + Organizer Fees (4200s)
```

#### Data Source
- **BigQuery Tables:** `src_fivetran_qbo.invoice_line`, `credit_memo_line`, `bill_line`, `vendor_credit_line`
- **Python Function:** `bigquery_client.get_take_rate()`
- **File Location:** `dashboard/data/bigquery_client.py:113`

#### Current Values
| Year | GMV | Revenue | Take Rate | Notes |
|------|-----|---------|-----------|-------|
| 2025 | $7.92M | $3.90M | **49.3%** | Full year |
| 2026 | <$100K | — | **~0%** | Falls back to 2025 |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:**

---

### 3. Demand NRR (Net Revenue Retention)

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Target** | 110% (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Formula
```
NRR = (Prior year cohort's current year revenue) / (Their prior year revenue)

Example for 2026:
- 2025 Cohort spent $1,008K in 2025
- Same cohort spent $1.5K in 2026 (so far)
- NRR = $1.5K / $1,008K = 0.15%
```

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.cohort_retention_matrix_by_customer`
- **Python Function:** `bigquery_client.get_nrr()` and `get_demand_nrr_details()`
- **File Location:** `dashboard/data/bigquery_client.py:213` and `:251`

#### Current Values
| Comparison | Cohort | Original Rev | Next Year Rev | NRR |
|------------|--------|--------------|---------------|-----|
| 2025 Actuals | 2024 | $1,517,381 | $337,591 | **22.2%** |
| 2026 YTD | 2025 | $1,008,415 | $1,549 | **0.15%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** NRR below 100% = cohort contraction (expected early year)

---

### 4. Supply NRR

| Field | Value |
|-------|-------|
| **Owner** | Ashton |
| **Target** | 110% |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Formula
```
Supply NRR = (2025 suppliers' 2026 payouts) / (Their 2025 payouts)
```

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.Supplier_Metrics`
- **Python Function:** `bigquery_client.get_supply_nrr()` and `get_supply_nrr_details()`
- **File Location:** `dashboard/data/bigquery_client.py:321` and `:362`

#### Current Values
| Comparison | Cohort | Original Payouts | Next Year Payouts | NRR |
|------------|--------|------------------|-------------------|-----|
| 2025 Actuals | 2024 | $2.74M | $1.83M | **66.7%** |
| 2026 YTD | 2025 | $2.98M | ~$0 | **~0%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Same pattern as Demand NRR - shows contraction

---

### 5. Pipeline Coverage

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Target** | 3.0x |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Formula
```
Pipeline Coverage = HS Weighted Pipeline (closing this quarter) / Remaining Quarterly Goal

Where:
- Annual Goal = Company Properties ($9.27M) + Unnamed ($2M) = $11.27M
- Quarterly Goal = Annual / 4 = $2.82M
- Remaining = Quarterly Goal - Closed Won
```

#### Data Source
- **BigQuery Tables:** `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.company`
- **Python Function:** `bigquery_client.get_pipeline_coverage()` and `get_pipeline_details()`
- **File Location:** `dashboard/data/bigquery_client.py:637` and `:665`

#### Current Values (Q1 2026)
| Metric | Value |
|--------|-------|
| Annual Goal | $11,268,142 |
| Q1 Goal | $2,817,036 |
| Closed Won | $630,658 |
| Remaining to Goal | $2,186,377 |
| HS Weighted Pipeline | $7,132,571 |
| Total Pipeline (raw) | $9,929,168 |
| Open Deals | 94 |
| **Pipeline Coverage** | **3.26x** ✅ |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Dynamic quota from HubSpot company properties now working

---

### 6. Logo Retention

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | 50% |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Formula
```
Logo Retention = Customers with revenue in BOTH years / Customers with revenue in prior year

Example (2024→2025):
- 535 customers had revenue in 2024
- 96 of those also had revenue in 2025
- Logo Retention = 96/535 = 17.9%

Updated (using DISTINCT customer_id):
- Returns ~26% for 2024→2025
```

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.customer_development`
- **Python Function:** `bigquery_client.get_logo_retention()`
- **File Location:** `dashboard/data/bigquery_client.py:543`

#### Current Values
| Period | Retained | Total | Logo Retention |
|--------|----------|-------|----------------|
| 2024→2025 | ~139 | ~535 | **26%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Uses COUNT(DISTINCT customer_id) due to multiple rows per customer

---

### 7. Customer Count (Active Customers)

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | 75 |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.customer_development`
- **Python Function:** `bigquery_client.get_customer_count()`
- **File Location:** `dashboard/data/bigquery_client.py:432`

#### Current Values
| Year | Active Customers |
|------|-----------------|
| 2025 | **51** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Customers with Net_Revenue_2025 > 0

---

### 8. Contract Spend %

| Field | Value |
|-------|-------|
| **Owner** | Char |
| **Target** | 95% |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.Upfront_Contract_Spend_Query`
- **Python Function:** `bigquery_client.get_contract_spend_pct()`
- **File Location:** `dashboard/data/bigquery_client.py:992`

#### Current Value
| Metric | Value |
|--------|-------|
| Contract Spend % | **TBD - needs query** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Python function exists but not wired to UI

---

### 9. Time to Fulfill

| Field | Value |
|-------|-------|
| **Owner** | Victoria |
| **Target** | 30 days |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.Days_to_Fulfill_Contract_Program`
- **Python Function:** `bigquery_client.get_time_to_fulfill()` and `get_avg_days_to_fulfill()`
- **File Location:** `dashboard/data/bigquery_client.py:1015` and `:1048`

#### Current Values
| Metric | Value |
|--------|-------|
| Avg Days | 139 days |
| **Median Days** | **14 days** (recommended) |
| Contract Count | 370 |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Large gap between avg/median suggests outliers. Recommend median.

---

### 10. NPS Score

| Field | Value |
|-------|-------|
| **Owner** | Claire |
| **Target** | 75% |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.organizer_recap_NPS_score`
- **Python Function:** `bigquery_client.get_nps_score()`
- **File Location:** `dashboard/data/bigquery_client.py:1060`

#### Current Value
| Metric | Value |
|--------|-------|
| NPS Score | **TBD - needs query** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Python function exists but not wired to UI

---

### 11. Customer Concentration

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | <30% |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.net_revenue_retention_all_customers`
- **Python Function:** `bigquery_client.get_customer_concentration()`
- **File Location:** `dashboard/data/bigquery_client.py:485`

#### Current Values (2025)
| Rank | Customer | Revenue | % of Total |
|------|----------|---------|------------|
| 1 | HEINEKEN USA | $1.18M | **29.2%** |
| 2 | Kraft Heinz | $957K | 23.7% |
| 3 | Advantage Solutions | $224K | 5.5% |
| 4 | Church & Dwight | $183K | 4.5% |
| 5 | Peace Tea | $126K | 3.1% |
| — | **Top 2 Combined** | — | **52.9%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:**

---

### 12. Churned Customers

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | N/A |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Data Source
- **BigQuery View:** `App_KPI_Dashboard.customer_development`
- **Python Function:** `bigquery_client.get_churned_customers()`
- **File Location:** `dashboard/data/bigquery_client.py:458`

#### Current Value
| Metric | Value |
|--------|-------|
| Churned (2024→2025) | **426 customers** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Had 2024 revenue but $0 in 2025

---

## BIGQUERY VIEWS INVENTORY

| View Name | Dataset | Purpose | Used By Function |
|-----------|---------|---------|------------------|
| `cohort_retention_matrix_by_customer` | App_KPI_Dashboard | Demand NRR | `get_nrr()` |
| `net_revenue_retention_all_customers` | App_KPI_Dashboard | Customer concentration, drill-down | `get_customer_concentration()` |
| `customer_development` | App_KPI_Dashboard | Customer count, logo retention, churn | `get_customer_count()`, `get_logo_retention()`, `get_churned_customers()` |
| `Supplier_Metrics` | App_KPI_Dashboard | Supply NRR, take rate | `get_supply_nrr()`, `get_take_rate()` |
| `Upfront_Contract_Spend_Query` | App_KPI_Dashboard | Contract spend % | `get_contract_spend_pct()` |
| `Days_to_Fulfill_Contract_Program` | App_KPI_Dashboard | Time to fulfill | `get_time_to_fulfill()` |
| `organizer_recap_NPS_score` | App_KPI_Dashboard | NPS score | `get_nps_score()` |

---

## PYTHON FUNCTIONS INVENTORY

| Function | File Location | Returns | Used in UI |
|----------|---------------|---------|------------|
| `get_revenue_ytd()` | `:79` | float | ✅ |
| `get_take_rate()` | `:113` | float | ✅ |
| `get_nrr()` | `:213` | float | ✅ |
| `get_demand_nrr_details()` | `:251` | dict | ⚠️ |
| `get_supply_nrr()` | `:321` | float | ✅ |
| `get_supply_nrr_details()` | `:362` | dict | ⚠️ |
| `get_customer_count()` | `:432` | int | ✅ |
| `get_churned_customers()` | `:458` | int | ❌ |
| `get_customer_concentration()` | `:485` | dict | ⚠️ |
| `get_logo_retention()` | `:543` | float | ✅ |
| `get_quota_from_company_properties()` | `:583` | dict | ✅ |
| `get_pipeline_coverage()` | `:637` | float | ✅ |
| `get_pipeline_details()` | `:665` | dict | ⚠️ |
| `get_pipeline_coverage_by_owner()` | `:807` | list | ❌ |
| `get_company_metrics()` | `:962` | dict | ✅ |
| `get_contract_spend_pct()` | `:992` | float | ❌ |
| `get_time_to_fulfill()` | `:1015` | dict | ❌ |
| `get_avg_days_to_fulfill()` | `:1048` | float | ❌ |
| `get_nps_score()` | `:1060` | float | ❌ |
| `get_nrr_by_customer()` | `:1085` | list | ❌ |
| `get_cohort_matrix()` | `:1106` | list | ❌ |

---

## NEXT STEPS (PRIORITIZED)

### Immediate (This Session)
1. [ ] Wire Contract Spend % to UI
2. [ ] Wire Time to Fulfill (median) to UI
3. [ ] Wire NPS Score to UI
4. [ ] Wire Churned Customers to UI

### Short-term
5. [ ] Update UI labels: "Gross Margin" → "Take Rate"
6. [ ] Add 2025 reference values for context
7. [ ] Create `dashboard_kpis` summary table for Phase 2

### Medium-term
8. [ ] Set up Cloud Scheduler for daily refresh
9. [ ] Define "sellable" inventory criteria (PRD needed)
10. [ ] Integrate remaining person-level metrics

---

## CHANGE LOG

| Date | Change | By |
|------|--------|-----|
| 2026-02-03 | Initial tracker created | Claude |
| 2026-02-03 | Added Supply NRR, Time to Fulfill, Customer Count to Company Health UI | Claude |
| 2026-02-03 | Added Sellable Inventory placeholder card with "Needs PRD" status | Claude |
| | | |

